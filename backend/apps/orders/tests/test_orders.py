"""Order endpoint + service-layer tests — atomic stock, state machine, ownership scoping, role gates.

These cover the rules in apps/orders/services.py — particularly the parts that are easiest to break in subtle ways
(stock decrement on create, restore on cancel, listing flip to/from OUT_OF_STOCK, terminal-state guards).

v3.1 catalog overhaul: the test factory now requires a Market + MeatCategory (passed via fixtures), the
listing's display name is `name_uz` (not `title`), and SOLD_OUT was renamed OUT_OF_STOCK.
"""
import pytest
from decimal import Decimal
from datetime import date, timedelta
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import User
from apps.listings.models import Listing, MeatCategory
from apps.markets.models import Market
from apps.orders.models import Order


def _client_for(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


@pytest.fixture
def _ctx(db):
    """Bundle the Market + Category for the order tests' Listing factory.

    Important: we deliberately do NOT depend on `verified_supplier` here. That fixture has a side effect — it flips
    is_verified=True on the shared supplier@test.local user — which would silently verify the user for any future
    test that combines `supplier_client` (unverified) with `_ctx`. The Market gets its own dedicated owner instead.
    """
    from apps.accounts.models import User
    owner, _ = User.objects.get_or_create(email="orders-market-owner@test.local", defaults={
        "full_name": "Orders Market Owner", "role": User.Role.SUPPLIER})
    market = Market.objects.create(slug="orders-market", name_uz="Orders Market", name_ru="Заказы Рынок",
                                   region="Tashkent", address="—", is_active=True,
                                   created_by=owner, updated_by=owner)
    category, _ = MeatCategory.objects.get_or_create(
        slug="mol-goshti", defaults={"name_uz": "Mol go'shti", "name_ru": "Говядина", "display_order": 10})
    return market, category


def _listing(supplier, ctx, qty="100.00", price="50000.00", status=Listing.Status.ACTIVE, slug="test"):
    """Test helper — same shape as before, just adapted to the v3.1 schema (FKs + name_uz)."""
    market, category = ctx
    l = Listing(
        supplier=supplier, market=market, category=category,
        slug=slug, name_uz="Test", name_ru="Тест",
        quantity_kg=qty, price_per_kg=price, location="Tashkent",
        available_from=date.today() + timedelta(days=1), status=status,
    )
    l._skip_price_history = True
    l.save()
    return l


@pytest.mark.django_db
class TestPlaceOrder:
    """POST /api/v1/orders/ — buyer-only, atomic stock decrement, total_price snapshot."""

    def test_buyer_places_order_decrements_stock_and_snapshots_price(self, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx, qty="100.00", price="50000.00")
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 201
        # total_price = quantity × price, frozen at order-creation time
        assert Decimal(r.data["total_price"]) == Decimal("500000.00")
        l.refresh_from_db()
        assert l.quantity_kg == Decimal("90.00") and l.status == Listing.Status.ACTIVE

    def test_exact_stock_order_flips_listing_to_sold_out(self, buyer_client, verified_supplier, _ctx):
        # PRD v2 §1: min order is 10kg for wholesale BY_WEIGHT listings; this test sizes the listing to
        # exactly 10kg so the order drains it completely.
        l = _listing(verified_supplier, _ctx, qty="10.00")
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 201
        l.refresh_from_db()
        assert l.quantity_kg == Decimal("0.00") and l.status == Listing.Status.OUT_OF_STOCK

    def test_oversell_blocked_with_field_error(self, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx, qty="10.00")
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "20.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 400 and "quantity_kg" in r.data

    def test_order_on_sold_out_listing_blocked(self, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx, qty="0.00", status=Listing.Status.OUT_OF_STOCK)
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 400

    def test_below_10kg_rejected_per_prd(self, buyer_client, verified_supplier, _ctx):
        # PRD v2 §1 wholesale minimum: anything < 10kg on a BY_WEIGHT listing must be rejected.
        l = _listing(verified_supplier, _ctx, qty="100.00")
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "5.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 400 and "quantity_kg" in r.data

    def test_catalog_operator_cannot_use_buyer_checkout(self, verified_supplier_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx)
        r = verified_supplier_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                               "delivery_address": "addr"}, format="json")
        assert r.status_code == 403


@pytest.mark.django_db
class TestCancelOrder:
    """Buyer-side cancel — only PENDING; restores stock; flips SOLD_OUT back to ACTIVE if applicable."""

    def test_buyer_cancels_pending_restores_stock(self, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx, qty="10.00")
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                          "delivery_address": "addr"}, format="json").data["id"]
        r = buyer_client.post(f"/api/v1/orders/{order_id}/cancel/")
        assert r.status_code == 200 and r.data["status"] == "CANCELLED"
        l.refresh_from_db()
        assert l.quantity_kg == Decimal("10.00")  # stock restored

    def test_cancel_reactivates_sold_out_listing(self, buyer_client, verified_supplier, _ctx):
        # Listing sized at exactly 10kg so a single qty=10 order drains the stock → flip to OUT_OF_STOCK,
        # then cancel restores it back to ACTIVE.
        l = _listing(verified_supplier, _ctx, qty="10.00")
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                          "delivery_address": "addr"}, format="json").data["id"]
        l.refresh_from_db(); assert l.status == Listing.Status.OUT_OF_STOCK
        buyer_client.post(f"/api/v1/orders/{order_id}/cancel/")
        l.refresh_from_db()
        assert l.status == Listing.Status.ACTIVE  # back to ACTIVE because there's stock again

    def test_buyer_cannot_cancel_confirmed(self, buyer_client, verified_supplier_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx)
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                          "delivery_address": "addr"}, format="json").data["id"]
        verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                      {"status": "CONFIRMED"}, format="json")
        r = buyer_client.post(f"/api/v1/orders/{order_id}/cancel/")
        assert r.status_code == 400


@pytest.mark.django_db
class TestSupplierStateMachine:
    """Catalog fulfillment ends at receipt-pending; only the buyer confirms final delivery."""

    @pytest.fixture
    def order_id(self, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx)
        return buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                      "delivery_address": "addr"}, format="json").data["id"]

    def test_full_forward_walk(self, verified_supplier_client, buyer_client, order_id):
        for s in ["CONFIRMED", "PROCESSING", "IN_TRANSIT", "DELIVERED_PENDING_CONFIRMATION"]:
            r = verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                              {"status": s}, format="json")
            assert r.status_code == 200 and r.data["status"] == s
        confirmed = buyer_client.post(f"/api/v1/orders/{order_id}/confirm-delivery/")
        assert confirmed.status_code == 200 and confirmed.data["status"] == "DELIVERED"

    def test_terminal_state_blocks_transition(self, verified_supplier_client, buyer_client, order_id):
        # Drive to DELIVERED then try to back-transition; backend returns 403 (PermissionDenied subclass)
        for s in ["CONFIRMED", "PROCESSING", "IN_TRANSIT", "DELIVERED_PENDING_CONFIRMATION"]:
            verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                          {"status": s}, format="json")
        buyer_client.post(f"/api/v1/orders/{order_id}/confirm-delivery/")
        r = verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                          {"status": "CONFIRMED"}, format="json")
        assert r.status_code == 403

    def test_supplier_cancel_restores_stock(self, verified_supplier_client, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx, qty="20.00")
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                          "delivery_address": "addr"}, format="json").data["id"]
        verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                      {"status": "CONFIRMED"}, format="json")
        verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                      {"status": "CANCELLED"}, format="json")
        l.refresh_from_db()
        assert l.quantity_kg == Decimal("20.00")  # stock restored just like buyer-side cancel


@pytest.mark.django_db
class TestOrderOwnership:
    """GET /api/v1/orders/{id}/ — readable by buyer or by listing owner; 404 to anyone else."""

    def test_buyer_sees_own_order(self, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        assert buyer_client.get(f"/api/v1/orders/{oid}/").status_code == 200

    def test_supplier_sees_orders_on_own_listing(self, verified_supplier_client, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        assert verified_supplier_client.get(f"/api/v1/orders/{oid}/").status_code == 200

    def test_unrelated_user_gets_404(self, buyer_client, verified_supplier, _ctx, db):
        from apps.accounts.models import User
        from rest_framework.test import APIClient
        from rest_framework_simplejwt.tokens import RefreshToken
        # Fresh buyer who didn't place this order
        other = User.objects.create_user(email="other@buy.local", password="X", full_name="X", role=User.Role.BUYER)
        other_client = APIClient()
        other_client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(other).access_token}")
        l = _listing(verified_supplier, _ctx)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        # Unrelated buyer gets 404 (not 403) — backend returns NotFound to avoid leaking that the order exists
        assert other_client.get(f"/api/v1/orders/{oid}/").status_code == 404


@pytest.mark.django_db
class TestCatalogOperatorGlobalOrders:
    """Historical listing owners remain data references; the one internal operator fulfills every order."""

    def _legacy_order(self, buyer_user, ctx, *, slug="legacy-order", quantity="10.00"):
        legacy_owner = User.objects.create_user(
            email=f"{slug}@supp.local", password="StrongPass123!",
            full_name="Legacy Supplier", role=User.Role.SUPPLIER)
        listing = _listing(legacy_owner, ctx, qty="40.00", slug=slug)
        order = Order.objects.create(
            buyer=buyer_user, listing=listing, quantity_kg=quantity,
            total_price="500000.00", delivery_address="addr")
        return legacy_owner, listing, order

    def test_operator_lists_reads_and_transitions_legacy_owned_order(
            self, verified_supplier_client, buyer_user, _ctx):
        legacy_owner, listing, order = self._legacy_order(buyer_user, _ctx)

        listed = verified_supplier_client.get("/api/v1/orders/supplier/")
        detail = verified_supplier_client.get(f"/api/v1/orders/{order.pk}/")
        advanced = verified_supplier_client.post(
            f"/api/v1/orders/supplier/{order.pk}/status/", {"status": "CONFIRMED"}, format="json")

        assert listed.status_code == 200
        assert order.pk in {row["id"] for row in listed.data["results"]}
        assert detail.status_code == 200
        assert advanced.status_code == 200 and advanced.data["status"] == Order.Status.CONFIRMED
        order.refresh_from_db()
        assert order.status == Order.Status.CONFIRMED
        assert order.listing.supplier_id == legacy_owner.id

    def test_legacy_owner_is_blocked_from_legacy_supplier_endpoints_and_detail(
            self, buyer_user, _ctx):
        legacy_owner, listing, order = self._legacy_order(
            buyer_user, _ctx, slug="blocked-legacy-order")
        client = _client_for(legacy_owner)

        assert client.get("/api/v1/orders/supplier/").status_code == 403
        assert client.get(f"/api/v1/orders/{order.pk}/").status_code == 404
        assert client.post(
            f"/api/v1/orders/supplier/{order.pk}/status/",
            {"status": "CONFIRMED"}, format="json").status_code == 403

    @pytest.mark.parametrize("role", [User.Role.QASSOB, User.Role.COURIER])
    def test_other_work_roles_cannot_access_catalog_order_endpoint(self, db, role):
        user = User.objects.create_user(
            email=f"isolated-{role.lower()}@test.local", password="StrongPass123!",
            full_name="Isolated Worker", role=role)

        assert _client_for(user).get("/api/v1/orders/supplier/").status_code == 403
