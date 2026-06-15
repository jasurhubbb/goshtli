"""Payment endpoint matrix — covers every surface that mobile + provider webhooks hit.

Coverage targets (each endpoint × auth state × order state × provider verdict):
  GeneratePayLinkView (POST /payments/orders/<id>/pay/)
    • happy-path: buyer authenticated, owns order, status UNPAID    → 200 + payment_url + PENDING
    • already-PAID order                                            → 409 (don't double-charge)
    • someone else's order                                          → 404 (filtered by buyer in queryset)
    • unauthenticated                                               → 401
    • retry after a prior FAILED attempt                            → 200 + fresh URL + fresh tx_id
  WebhookView (POST /payments/webhook/)
    • valid mock signature, status=PAID                             → 200 + order flips to PAID
    • valid mock signature, status=FAILED                           → 200 + order flips to FAILED
    • invalid signature                                             → 401
    • malformed JSON                                                → 400
    • status not in {PAID,FAILED,REFUNDED}                          → 400
    • tx_id not matching any order                                  → 404
    • webhook for already-PAID order (replay)                       → 200 noop (idempotent, never flips PAID→FAILED)
  mock_checkout_page (GET /payments/mock/<tx_id>/)
    • renders HTML with the order id + amount visible
  Provider selection
    • PAYMENT_PROVIDER=mock (default) returns MockProvider
    • PAYMENT_PROVIDER=payme returns PaymeProvider
    • Unknown PAYMENT_PROVIDER falls back to MockProvider

These run with PAYMENT_PROVIDER=mock so we don't need any external services or live merchant credentials.
"""
import hmac
import hashlib
import json
from datetime import date, timedelta
from decimal import Decimal

import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.listings.models import Listing, MeatCategory
from apps.markets.models import Market
from apps.orders.models import Order
from apps.payments.providers import MockProvider, PaymeProvider, get_provider


# ---------- Fixtures ----------

@pytest.fixture
def _ctx(db):
    """Market + Category — duplicated from orders/tests because each test app should be self-contained.
    Using a unique market owner so this fixture doesn't side-effect the supplier_user shared fixture."""
    owner, _ = User.objects.get_or_create(email="payments-market-owner@test.local", defaults={
        "full_name": "Payments Market Owner", "role": User.Role.SUPPLIER})
    market = Market.objects.create(slug="payments-market", name_uz="Payments Market", name_ru="Платежи Рынок",
                                   region="Tashkent", address="—", is_active=True,
                                   created_by=owner, updated_by=owner)
    category, _ = MeatCategory.objects.get_or_create(
        slug="mol-goshti", defaults={"name_uz": "Mol go'shti", "name_ru": "Говядина", "display_order": 10})
    return market, category


@pytest.fixture
def order(buyer_user, verified_supplier, _ctx):
    """A placed PENDING order — bypass the API to set up state quickly for payment tests."""
    market, category = _ctx
    listing = Listing(supplier=verified_supplier, market=market, category=category,
                      slug="order-listing", name_uz="Test", name_ru="Тест",
                      quantity_kg=Decimal("100.00"), price_per_kg=Decimal("50000.00"),
                      location="Tashkent", available_from=date.today() + timedelta(days=1),
                      status=Listing.Status.ACTIVE)
    listing._skip_price_history = True
    listing.save()
    return Order.objects.create(buyer=buyer_user, listing=listing,
                                quantity_kg=Decimal("2.00"), total_price=Decimal("100000.00"),
                                delivery_address="addr", status=Order.Status.PENDING)


def _sign(body: bytes) -> str:
    """Mimic the in-page JS's HMAC signing so the webhook test acts like the mock page would."""
    return hmac.new(MockProvider._secret().encode(), body, hashlib.sha256).hexdigest()


# ---------- GeneratePayLinkView ----------

@pytest.mark.django_db
class TestGeneratePayLink:
    URL = "/api/v1/payments/orders/{id}/pay/"

    def test_buyer_gets_pay_url_and_pending_status(self, buyer_client, order):
        r = buyer_client.post(self.URL.format(id=order.id), {}, format="json")
        assert r.status_code == 200
        assert "payment_url" in r.data and r.data["payment_url"]
        assert r.data["payment_status"] == Order.PaymentStatus.PENDING
        assert r.data["provider"] == "mock"
        order.refresh_from_db()
        assert order.payment_status == Order.PaymentStatus.PENDING
        assert order.payment_provider == "mock"
        assert order.payment_provider_tx_id.startswith("mock_")

    def test_already_paid_order_returns_409(self, buyer_client, order):
        order.payment_status = Order.PaymentStatus.PAID
        order.save(update_fields=["payment_status"])
        r = buyer_client.post(self.URL.format(id=order.id), {}, format="json")
        assert r.status_code == 409

    def test_other_buyer_cannot_pay_my_order(self, order, db):
        attacker = User.objects.create_user(email="attacker@test.local", password="X",
                                            full_name="Attacker", role=User.Role.BUYER)
        from rest_framework_simplejwt.tokens import RefreshToken
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(attacker).access_token}")
        r = client.post(self.URL.format(id=order.id), {}, format="json")
        # get_object_or_404 filters by buyer, so the attacker sees a 404 rather than a 403 — chosen
        # deliberately so we don't leak the existence of other buyers' orders.
        assert r.status_code == 404

    def test_anonymous_blocked(self, api, order):
        r = api.post(self.URL.format(id=order.id), {}, format="json")
        assert r.status_code == 401

    def test_retry_after_failed_attempt_mints_fresh_url_and_tx_id(self, buyer_client, order):
        first = buyer_client.post(self.URL.format(id=order.id), {}, format="json")
        assert first.status_code == 200
        # Simulate provider rejection — buyer taps "Qaytadan urinish".
        order.refresh_from_db()
        order.payment_status = Order.PaymentStatus.FAILED
        order.save(update_fields=["payment_status"])
        prev_tx = order.payment_provider_tx_id
        prev_url = order.payment_url

        second = buyer_client.post(self.URL.format(id=order.id), {}, format="json")
        assert second.status_code == 200
        assert second.data["payment_url"] != prev_url
        order.refresh_from_db()
        assert order.payment_provider_tx_id != prev_tx
        assert order.payment_status == Order.PaymentStatus.PENDING


# ---------- WebhookView ----------

@pytest.mark.django_db
class TestWebhook:
    URL = "/api/v1/payments/webhook/"

    def _place_pending(self, order):
        # Move order into PENDING with a known tx_id so we can target it from a forged webhook body.
        order.payment_status = Order.PaymentStatus.PENDING
        order.payment_provider = "mock"
        order.payment_provider_tx_id = "mock_abcdef0123456789"
        order.save(update_fields=["payment_status", "payment_provider", "payment_provider_tx_id"])
        return order

    def test_valid_signature_paid_flips_order_to_paid(self, api, order):
        self._place_pending(order)
        body = json.dumps({"provider_tx_id": order.payment_provider_tx_id, "status": "PAID"}).encode()
        r = api.post(self.URL, data=body, content_type="application/json", HTTP_X_SIGNATURE=_sign(body))
        assert r.status_code == 200 and r.data.get("ok") is True
        order.refresh_from_db()
        assert order.payment_status == Order.PaymentStatus.PAID

    def test_valid_signature_failed_flips_order_to_failed(self, api, order):
        self._place_pending(order)
        body = json.dumps({"provider_tx_id": order.payment_provider_tx_id, "status": "FAILED"}).encode()
        r = api.post(self.URL, data=body, content_type="application/json", HTTP_X_SIGNATURE=_sign(body))
        assert r.status_code == 200
        order.refresh_from_db()
        assert order.payment_status == Order.PaymentStatus.FAILED

    def test_invalid_signature_rejected(self, api, order):
        self._place_pending(order)
        body = json.dumps({"provider_tx_id": order.payment_provider_tx_id, "status": "PAID"}).encode()
        r = api.post(self.URL, data=body, content_type="application/json", HTTP_X_SIGNATURE="bad-sig")
        assert r.status_code == 401
        order.refresh_from_db()
        assert order.payment_status == Order.PaymentStatus.PENDING                # untouched

    def test_malformed_json_rejected(self, api):
        body = b"not-json{"
        r = api.post(self.URL, data=body, content_type="application/json", HTTP_X_SIGNATURE=_sign(body))
        assert r.status_code == 400

    def test_unknown_status_rejected(self, api, order):
        self._place_pending(order)
        body = json.dumps({"provider_tx_id": order.payment_provider_tx_id, "status": "WEIRD"}).encode()
        r = api.post(self.URL, data=body, content_type="application/json", HTTP_X_SIGNATURE=_sign(body))
        assert r.status_code == 400

    def test_unknown_tx_id_returns_404(self, api):
        body = json.dumps({"provider_tx_id": "mock_ghost", "status": "PAID"}).encode()
        r = api.post(self.URL, data=body, content_type="application/json", HTTP_X_SIGNATURE=_sign(body))
        assert r.status_code == 404

    def test_replay_against_already_paid_is_noop(self, api, order):
        self._place_pending(order)
        order.payment_status = Order.PaymentStatus.PAID
        order.save(update_fields=["payment_status"])
        # Now an old (or attacker-replayed) FAILED webhook lands — must NOT flip PAID → FAILED.
        body = json.dumps({"provider_tx_id": order.payment_provider_tx_id, "status": "FAILED"}).encode()
        r = api.post(self.URL, data=body, content_type="application/json", HTTP_X_SIGNATURE=_sign(body))
        assert r.status_code == 200 and r.data.get("noop") is True
        order.refresh_from_db()
        assert order.payment_status == Order.PaymentStatus.PAID                   # stayed PAID


# ---------- mock_checkout_page ----------

@pytest.mark.django_db
class TestMockCheckoutPage:
    def test_renders_html_with_order_meta(self, api):
        r = api.get("/api/v1/payments/mock/mock_test_tx_123/", {"order_id": "42", "amount": "150000.00"})
        assert r.status_code == 200
        body = r.content.decode()
        assert "MOCK" in body and "42" in body and "150000.00" in body


# ---------- Provider selection ----------

@pytest.mark.django_db
class TestProviderSelection:
    def test_default_is_mock(self, settings, monkeypatch):
        monkeypatch.delenv("PAYMENT_PROVIDER", raising=False)
        assert isinstance(get_provider(), MockProvider)

    def test_explicit_payme_returns_payme(self, monkeypatch):
        monkeypatch.setenv("PAYMENT_PROVIDER", "payme")
        assert isinstance(get_provider(), PaymeProvider)

    def test_unknown_provider_falls_back_to_mock(self, monkeypatch):
        monkeypatch.setenv("PAYMENT_PROVIDER", "uzcard-direct-someday")
        assert isinstance(get_provider(), MockProvider)
