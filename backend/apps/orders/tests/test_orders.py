"""Order endpoint + service-layer tests — atomic stock, state machine, ownership scoping, role gates.

These cover the rules in apps/orders/services.py — particularly the parts that are easiest to break in subtle ways
(stock decrement on create, restore on cancel, listing flip to/from SOLD_OUT, terminal-state guards).
"""
import pytest
from decimal import Decimal
from datetime import date, timedelta

from apps.listings.models import Listing
from apps.orders.models import Order


def _listing(supplier, qty="100.00", price="50000.00", status=Listing.Status.ACTIVE):
    return Listing.objects.create(supplier=supplier, title="Test", meat_type=Listing.MeatType.BEEF,
        quantity_kg=qty, price_per_kg=price, location="Tashkent",
        available_from=date.today() + timedelta(days=1), status=status)


@pytest.mark.django_db
class TestPlaceOrder:
    """POST /api/v1/orders/ — buyer-only, atomic stock decrement, total_price snapshot."""

    def test_buyer_places_order_decrements_stock_and_snapshots_price(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier, qty="100.00", price="50000.00")
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 201
        # total_price = quantity × price, frozen at order-creation time
        assert Decimal(r.data["total_price"]) == Decimal("500000.00")
        l.refresh_from_db()
        assert l.quantity_kg == Decimal("90.00") and l.status == Listing.Status.ACTIVE

    def test_exact_stock_order_flips_listing_to_sold_out(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier, qty="5.00")
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "5.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 201
        l.refresh_from_db()
        assert l.quantity_kg == Decimal("0.00") and l.status == Listing.Status.SOLD_OUT

    def test_oversell_blocked_with_field_error(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier, qty="5.00")
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 400 and "quantity_kg" in r.data

    def test_order_on_sold_out_listing_blocked(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier, qty="0.00", status=Listing.Status.SOLD_OUT)
        r = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "1.00",
                                                   "delivery_address": "addr"}, format="json")
        assert r.status_code == 400

    def test_supplier_can_also_place_orders_v2_unified_user(self, verified_supplier_client, verified_supplier):
        # v2 unified user model: a supplier can also buy from OTHER suppliers' listings (or technically their own — we don't
        # forbid that at the API level; UI can hide the order button when supplier == self). Used to be 403 in v1.
        l = _listing(verified_supplier)
        r = verified_supplier_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "1.00",
                                                               "delivery_address": "addr"}, format="json")
        assert r.status_code == 201


@pytest.mark.django_db
class TestCancelOrder:
    """Buyer-side cancel — only PENDING; restores stock; flips SOLD_OUT back to ACTIVE if applicable."""

    def test_buyer_cancels_pending_restores_stock(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier, qty="10.00")
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "5.00",
                                                          "delivery_address": "addr"}, format="json").data["id"]
        r = buyer_client.post(f"/api/v1/orders/{order_id}/cancel/")
        assert r.status_code == 200 and r.data["status"] == "CANCELLED"
        l.refresh_from_db()
        assert l.quantity_kg == Decimal("10.00")  # stock restored

    def test_cancel_reactivates_sold_out_listing(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier, qty="5.00")
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "5.00",
                                                          "delivery_address": "addr"}, format="json").data["id"]
        l.refresh_from_db(); assert l.status == Listing.Status.SOLD_OUT
        buyer_client.post(f"/api/v1/orders/{order_id}/cancel/")
        l.refresh_from_db()
        assert l.status == Listing.Status.ACTIVE  # back to ACTIVE because there's stock again

    def test_buyer_cannot_cancel_confirmed(self, buyer_client, verified_supplier_client, verified_supplier):
        l = _listing(verified_supplier)
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "1.00",
                                                          "delivery_address": "addr"}, format="json").data["id"]
        verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                      {"status": "CONFIRMED"}, format="json")
        r = buyer_client.post(f"/api/v1/orders/{order_id}/cancel/")
        assert r.status_code == 400


@pytest.mark.django_db
class TestSupplierStateMachine:
    """Supplier-driven status transitions — PENDING → CONFIRMED → PROCESSING → IN_TRANSIT → DELIVERED."""

    @pytest.fixture
    def order_id(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier)
        return buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "1.00",
                                                      "delivery_address": "addr"}, format="json").data["id"]

    def test_full_forward_walk(self, verified_supplier_client, order_id):
        for s in ["CONFIRMED", "PROCESSING", "IN_TRANSIT", "DELIVERED"]:
            r = verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                              {"status": s}, format="json")
            assert r.status_code == 200 and r.data["status"] == s

    def test_terminal_state_blocks_transition(self, verified_supplier_client, order_id):
        # Drive to DELIVERED then try to back-transition; backend returns 403 (PermissionDenied subclass)
        for s in ["CONFIRMED", "PROCESSING", "IN_TRANSIT", "DELIVERED"]:
            verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                          {"status": s}, format="json")
        r = verified_supplier_client.post(f"/api/v1/orders/supplier/{order_id}/status/",
                                          {"status": "CONFIRMED"}, format="json")
        assert r.status_code == 403

    def test_supplier_cancel_restores_stock(self, verified_supplier_client, buyer_client, verified_supplier):
        l = _listing(verified_supplier, qty="20.00")
        order_id = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "5.00",
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

    def test_buyer_sees_own_order(self, buyer_client, verified_supplier):
        l = _listing(verified_supplier)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "1.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        assert buyer_client.get(f"/api/v1/orders/{oid}/").status_code == 200

    def test_supplier_sees_orders_on_own_listing(self, verified_supplier_client, buyer_client, verified_supplier):
        l = _listing(verified_supplier)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "1.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        assert verified_supplier_client.get(f"/api/v1/orders/{oid}/").status_code == 200

    def test_unrelated_user_gets_404(self, buyer_client, verified_supplier, db):
        from apps.accounts.models import User
        from rest_framework.test import APIClient
        from rest_framework_simplejwt.tokens import RefreshToken
        # Fresh buyer who didn't place this order
        other = User.objects.create_user(email="other@buy.local", password="X", full_name="X", role=User.Role.BUYER)
        other_client = APIClient()
        other_client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(other).access_token}")
        l = _listing(verified_supplier)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "1.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        # Unrelated buyer gets 404 (not 403) — backend returns NotFound to avoid leaking that the order exists
        assert other_client.get(f"/api/v1/orders/{oid}/").status_code == 404
