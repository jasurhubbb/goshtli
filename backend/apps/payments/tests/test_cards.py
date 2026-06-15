"""Cards + pay-with-card endpoint matrix.

Coverage:
  GET    /payments/cards/                    — owner sees own cards; anonymous gets 401
  POST   /payments/cards/                    — happy path (each brand), make_default flag, bad PAN/CVC/expiry
  DELETE /payments/cards/<id>/               — owner can; another user gets 404
  POST   /payments/cards/<id>/set-default/   — atomic promote; old default cleared
  POST   /payments/orders/<id>/pay-with-card/ — happy path, already-paid 409, expired-card 400, foreign-card 404
"""
from datetime import date, timedelta
from decimal import Decimal

import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.listings.models import Listing, MeatCategory
from apps.markets.models import Market
from apps.orders.models import Order
from apps.payments.cards import detect_brand
from apps.payments.models import Card


# ---------- Fixtures ----------

@pytest.fixture
def _ctx(db):
    """Market + Category bundle. Same self-contained pattern as other test modules."""
    owner, _ = User.objects.get_or_create(email="cards-owner@test.local", defaults={
        "full_name": "Cards Owner", "role": User.Role.SUPPLIER})
    market = Market.objects.create(slug="cards-market", name_uz="Cards Market", name_ru="Кардс",
                                   region="Tashkent", address="—", is_active=True,
                                   created_by=owner, updated_by=owner)
    category, _ = MeatCategory.objects.get_or_create(
        slug="mol-goshti", defaults={"name_uz": "Mol go'shti", "name_ru": "Говядина", "display_order": 10})
    return market, category


@pytest.fixture
def order(buyer_user, verified_supplier, _ctx):
    market, category = _ctx
    listing = Listing(supplier=verified_supplier, market=market, category=category,
                      slug="card-order", name_uz="Test", name_ru="Тест",
                      quantity_kg=Decimal("100.00"), price_per_kg=Decimal("50000.00"),
                      location="Tashkent", available_from=date.today() + timedelta(days=1),
                      status=Listing.Status.ACTIVE)
    listing._skip_price_history = True
    listing.save()
    return Order.objects.create(buyer=buyer_user, listing=listing,
                                quantity_kg=Decimal("10.00"), total_price=Decimal("500000.00"),
                                delivery_address="addr", status=Order.Status.PENDING)


def _valid_payload(make_default: bool = False) -> dict:
    """A working POST body — Visa BIN '4', exp 12/2030, CVC 123."""
    return {
        "pan": "4242 4242 4242 4242",
        "expires_mm": 12,
        "expires_yy": 30,                                      # 2-digit year — server normalizes to 2030
        "cvc": "123",
        "holder_name": "JASUR M",
        "phone_for_sms": "+998901234567",
        "make_default": make_default,
    }


# ---------- BIN detection ----------

@pytest.mark.django_db
class TestBinDetection:
    def test_visa(self): assert detect_brand("4242424242424242") == Card.Brand.VISA
    def test_mastercard(self): assert detect_brand("5555555555554444") == Card.Brand.MASTERCARD
    def test_humo(self): assert detect_brand("9860123412341234") == Card.Brand.HUMO
    def test_uzcard(self): assert detect_brand("8600123412341234") == Card.Brand.UZCARD
    def test_unknown(self): assert detect_brand("9999123412341234") == Card.Brand.UNKNOWN


# ---------- Card list / create ----------

@pytest.mark.django_db
class TestCardCreate:
    URL = "/api/v1/payments/cards/"

    def test_anonymous_blocked(self, api):
        r = api.post(self.URL, _valid_payload(), format="json")
        assert r.status_code == 401

    def test_happy_path_first_card_is_default(self, buyer_client):
        r = buyer_client.post(self.URL, _valid_payload(), format="json")
        assert r.status_code == 201
        assert r.data["last_4"] == "4242"
        assert r.data["brand"] == "VISA"
        assert r.data["expires_year"] == 2030                  # normalized from 2-digit input
        assert r.data["is_default"] is True                    # first card auto-defaults

    def test_second_card_not_default_unless_requested(self, buyer_client):
        buyer_client.post(self.URL, _valid_payload(), format="json")               # default
        second = _valid_payload(); second["pan"] = "5555 5555 5555 4444"           # MC, different last_4
        r = buyer_client.post(self.URL, second, format="json")
        assert r.status_code == 201 and r.data["is_default"] is False

    def test_make_default_clears_previous_default(self, buyer_client, buyer_user):
        first = buyer_client.post(self.URL, _valid_payload(), format="json").data
        second = _valid_payload(); second["pan"] = "5555 5555 5555 4444"; second["make_default"] = True
        r = buyer_client.post(self.URL, second, format="json")
        assert r.status_code == 201 and r.data["is_default"] is True
        old = Card.objects.get(pk=first["id"])
        assert old.is_default is False

    def test_bad_pan_rejected(self, buyer_client):
        p = _valid_payload(); p["pan"] = "1234"
        r = buyer_client.post(self.URL, p, format="json")
        assert r.status_code == 400

    def test_bad_cvc_rejected_for_international(self, buyer_client):
        # CVC format check still applies when the buyer SUPPLIES one. For VISA / MASTERCARD the
        # backend doesn't require it but a malformed value (2 digits) is still a hard reject so the
        # buyer's typo is caught before the card is saved.
        p = _valid_payload(); p["cvc"] = "12"
        r = buyer_client.post(self.URL, p, format="json")
        assert r.status_code == 400

    def test_humo_card_with_no_cvc_accepted(self, buyer_client):
        # UZ-issued HUMO cards don't have a CVC. The mobile add-sheet hides the field and sends an empty
        # string; backend must accept that without complaint.
        p = _valid_payload()
        p["pan"] = "9860 1234 5678 9012"
        p["cvc"] = ""
        r = buyer_client.post(self.URL, p, format="json")
        assert r.status_code == 201
        assert r.data["brand"] == "HUMO"

    def test_uzcard_with_no_cvc_accepted(self, buyer_client):
        p = _valid_payload()
        p["pan"] = "8600 1234 5678 9012"
        p["cvc"] = ""
        r = buyer_client.post(self.URL, p, format="json")
        assert r.status_code == 201
        assert r.data["brand"] == "UZCARD"

    def test_bad_month_rejected(self, buyer_client):
        p = _valid_payload(); p["expires_mm"] = 13
        r = buyer_client.post(self.URL, p, format="json")
        assert r.status_code == 400

    def test_pan_and_cvc_are_never_returned(self, buyer_client):
        r = buyer_client.post(self.URL, _valid_payload(), format="json")
        assert "pan" not in r.data and "cvc" not in r.data


@pytest.mark.django_db
class TestCardList:
    URL = "/api/v1/payments/cards/"

    def test_owner_sees_own_cards_only(self, buyer_client, buyer_user, db):
        # Insert two cards for buyer + one for an unrelated user; only the buyer's pair shows.
        Card.objects.create(user=buyer_user, last_4="1111", brand="VISA", expires_month=1, expires_year=2030, is_default=True)
        Card.objects.create(user=buyer_user, last_4="2222", brand="HUMO", expires_month=2, expires_year=2030)
        stranger = User.objects.create_user(email="stranger@test.local", password="X",
                                            full_name="Stranger", role=User.Role.BUYER)
        Card.objects.create(user=stranger, last_4="9999", brand="VISA", expires_month=3, expires_year=2030)
        r = buyer_client.get(self.URL)
        assert r.status_code == 200
        last_4s = {c["last_4"] for c in r.data}
        assert last_4s == {"1111", "2222"}
        # default first per Meta.ordering
        assert r.data[0]["last_4"] == "1111"


@pytest.mark.django_db
class TestCardDelete:
    def test_owner_can_delete(self, buyer_client, buyer_user):
        c = Card.objects.create(user=buyer_user, last_4="3333", brand="VISA",
                                expires_month=1, expires_year=2030, is_default=True)
        r = buyer_client.delete(f"/api/v1/payments/cards/{c.id}/")
        assert r.status_code == 204
        assert not Card.objects.filter(pk=c.id).exists()

    def test_stranger_cannot_delete(self, db, buyer_user):
        c = Card.objects.create(user=buyer_user, last_4="4444", brand="VISA",
                                expires_month=1, expires_year=2030)
        stranger = User.objects.create_user(email="s2@test.local", password="X",
                                            full_name="S2", role=User.Role.BUYER)
        from rest_framework_simplejwt.tokens import RefreshToken
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(stranger).access_token}")
        r = client.delete(f"/api/v1/payments/cards/{c.id}/")
        assert r.status_code == 404


@pytest.mark.django_db
class TestSetDefault:
    def test_set_default_swaps_atomically(self, buyer_client, buyer_user):
        a = Card.objects.create(user=buyer_user, last_4="aaaa"[:4], brand="VISA",
                                expires_month=1, expires_year=2030, is_default=True)
        # Use a non-aaaa string for last_4 since it must be 4 digits; we override afterwards via update.
        b = Card.objects.create(user=buyer_user, last_4="0000", brand="HUMO",
                                expires_month=2, expires_year=2030, is_default=False)
        r = buyer_client.post(f"/api/v1/payments/cards/{b.id}/set-default/")
        assert r.status_code == 200
        a.refresh_from_db(); b.refresh_from_db()
        assert a.is_default is False and b.is_default is True


# ---------- Pay with card ----------

@pytest.mark.django_db
class TestPayWithCard:
    def _url(self, oid: int) -> str: return f"/api/v1/payments/orders/{oid}/pay-with-card/"

    def test_happy_path_marks_order_paid(self, buyer_client, buyer_user, order):
        c = Card.objects.create(user=buyer_user, last_4="4242", brand="VISA",
                                expires_month=12, expires_year=2030, is_default=True)
        r = buyer_client.post(self._url(order.id),
                              {"card_id": c.id, "sms_code": "anything"}, format="json")
        assert r.status_code == 200
        assert r.data["payment_status"] == "PAID"
        assert r.data["card_last_4"] == "4242"
        order.refresh_from_db()
        assert order.payment_status == Order.PaymentStatus.PAID
        assert order.payment_provider == "mock"
        assert order.payment_provider_tx_id.startswith("mock_card_")

    def test_empty_sms_code_still_succeeds_mock_mode(self, buyer_client, buyer_user, order):
        # Per product decision: mock mode skips SMS entirely. Empty / wrong / missing — all accepted.
        c = Card.objects.create(user=buyer_user, last_4="4242", brand="VISA",
                                expires_month=12, expires_year=2030, is_default=True)
        r = buyer_client.post(self._url(order.id), {"card_id": c.id}, format="json")
        assert r.status_code == 200

    def test_already_paid_returns_409(self, buyer_client, buyer_user, order):
        order.payment_status = Order.PaymentStatus.PAID
        order.save(update_fields=["payment_status"])
        c = Card.objects.create(user=buyer_user, last_4="4242", brand="VISA",
                                expires_month=12, expires_year=2030, is_default=True)
        r = buyer_client.post(self._url(order.id), {"card_id": c.id}, format="json")
        assert r.status_code == 409

    def test_expired_card_rejected(self, buyer_client, buyer_user, order):
        # 01/2024 is in the past relative to test-run date — `is_expired` returns True.
        c = Card.objects.create(user=buyer_user, last_4="0000", brand="VISA",
                                expires_month=1, expires_year=2024, is_default=True)
        r = buyer_client.post(self._url(order.id), {"card_id": c.id}, format="json")
        assert r.status_code == 400

    def test_foreign_card_404(self, buyer_client, buyer_user, order, db):
        stranger = User.objects.create_user(email="other@buy.local", password="X",
                                            full_name="X", role=User.Role.BUYER)
        c = Card.objects.create(user=stranger, last_4="9999", brand="VISA",
                                expires_month=12, expires_year=2030, is_default=True)
        r = buyer_client.post(self._url(order.id), {"card_id": c.id}, format="json")
        assert r.status_code == 404

    def test_foreign_order_404(self, buyer_user, order, db):
        # Another buyer trying to pay this order — backend filters by buyer first.
        attacker = User.objects.create_user(email="a@b.local", password="X",
                                            full_name="A", role=User.Role.BUYER)
        c = Card.objects.create(user=attacker, last_4="1234", brand="VISA",
                                expires_month=12, expires_year=2030, is_default=True)
        from rest_framework_simplejwt.tokens import RefreshToken
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(attacker).access_token}")
        r = client.post(self._url(order.id), {"card_id": c.id}, format="json")
        assert r.status_code == 404
