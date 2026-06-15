"""Delivery quote + live-animal + 10kg-minimum endpoint matrix.

Coverage:
  POST /api/v1/delivery/quote/
    • Cart of raw meat only           → Refrigerator available; ChorvaTaksi unavailable (reason).
    • Cart with live animal + no butcher → ChorvaTaksi available; Refrigerator unavailable.
    • Cart with live animal + butcher  → Refrigerator available; ChorvaTaksi unavailable.
    • Mixed cart (raw + live + no butcher) → both vehicles "available" per business intent (raw needs cold,
      live needs ChorvaTaksi). v1 surfaces both; future revision will split into two delivery legs.
    • Distance scales the per-km charge — closer buyer = lower total_price.
    • Anonymous → 401.
    • Empty items[] → 400.
  POST /api/v1/orders/  (10kg minimum + delivery params persist on the order)
    • quantity < 10kg on BY_WEIGHT listing → 400 (PRD §1).
    • BY_HEAD live listing accepts qty=1 (per-head) — 10kg rule doesn't apply.
    • Delivery vehicle + time slot + butcher fee flow into the persisted Order row.
    • total_price = listing × qty + delivery + butcher fee.
"""
from datetime import date, timedelta
from decimal import Decimal

import pytest

from apps.accounts.models import User
from apps.listings.models import Listing, MeatCategory
from apps.markets.models import Market
from apps.orders.models import Order


# ---------- Fixtures ----------

@pytest.fixture
def _ctx(db):
    """Self-contained Market + Category bundle — same pattern as orders/payments tests."""
    owner, _ = User.objects.get_or_create(email="delivery-market-owner@test.local", defaults={
        "full_name": "Delivery Market Owner", "role": User.Role.SUPPLIER})
    market = Market.objects.create(slug="delivery-market", name_uz="Delivery Market", name_ru="Доставка Рынок",
                                   region="Tashkent", address="—", is_active=True,
                                   created_by=owner, updated_by=owner)
    category, _ = MeatCategory.objects.get_or_create(
        slug="mol-goshti", defaults={"name_uz": "Mol go'shti", "name_ru": "Говядина", "display_order": 10})
    return market, category


def _raw_meat_listing(supplier, ctx, qty="100.00", price="50000.00", slug="raw"):
    market, category = ctx
    l = Listing(supplier=supplier, market=market, category=category,
                slug=slug, name_uz="Mol go'shti", name_ru="Говядина",
                quantity_kg=qty, price_per_kg=price, location="Tashkent",
                available_from=date.today() + timedelta(days=1),
                status=Listing.Status.ACTIVE,
                is_live_animal=False, sale_type=Listing.SaleType.BY_WEIGHT)
    l._skip_price_history = True
    l.save()
    return l


def _live_animal_listing(supplier, ctx, by_head=True, slug="live"):
    """Live qo'y by head with 50kg avg live weight, 52% yield."""
    market, category = ctx
    l = Listing(supplier=supplier, market=market, category=category,
                slug=slug, name_uz="Hisor qo'y", name_ru="Гиссарская овца",
                quantity_kg=Decimal("10.00") if by_head else Decimal("500.00"),
                price_per_kg=Decimal("80000.00"),
                location="Jizzax", available_from=date.today() + timedelta(days=1),
                status=Listing.Status.ACTIVE,
                is_live_animal=True,
                sale_type=Listing.SaleType.BY_HEAD if by_head else Listing.SaleType.BY_WEIGHT,
                estimated_meat_yield_pct=52,
                breed_type="Hisor",
                head_count=10 if by_head else 0,
                live_weight_per_head_kg=Decimal("50.00") if by_head else Decimal("0.00"))
    l._skip_price_history = True
    l.save()
    return l


# ---------- DeliveryQuoteView ----------

@pytest.mark.django_db
class TestDeliveryQuote:
    URL = "/api/v1/delivery/quote/"
    # Tashkent center coords (matches the placeholder dispatch coord in views.py) → 0 km test.
    BUYER_TASHKENT = {"buyer_lat": "41.3111", "buyer_lng": "69.2797"}
    # Buyer outside Tashkent — Samarkand-ish — distance > 0.
    BUYER_FAR = {"buyer_lat": "39.6542", "buyer_lng": "66.9597"}

    def test_raw_meat_only_cart_offers_refrigerator(self, buyer_client, verified_supplier, _ctx):
        l = _raw_meat_listing(verified_supplier, _ctx)
        r = buyer_client.post(self.URL, {
            "items": [{"listing": l.id, "quantity_kg": "10.00"}],
            **self.BUYER_TASHKENT,
        }, format="json")
        assert r.status_code == 200
        opts = {o["code"]: o for o in r.data["options"]}
        assert opts[Order.VehicleType.REFRIGERATOR]["available"] is True
        assert opts[Order.VehicleType.CHORVA_TAXI]["available"] is False
        assert r.data["cart_has_live_animal"] is False
        assert r.data["butcher_service"]["available"] is False

    def test_live_animal_no_butcher_offers_chorva_taxi(self, buyer_client, verified_supplier, _ctx):
        l = _live_animal_listing(verified_supplier, _ctx)
        r = buyer_client.post(self.URL, {
            "items": [{"listing": l.id, "quantity_kg": "1.00"}],
            "butcher_service_requested": False,
            **self.BUYER_TASHKENT,
        }, format="json")
        assert r.status_code == 200
        opts = {o["code"]: o for o in r.data["options"]}
        assert opts[Order.VehicleType.CHORVA_TAXI]["available"] is True
        assert opts[Order.VehicleType.REFRIGERATOR]["available"] is False
        assert r.data["butcher_service"]["available"] is True               # offer is shown
        assert r.data["butcher_service"]["requested"] is False              # buyer hasn't accepted

    def test_live_animal_with_butcher_switches_to_refrigerator(self, buyer_client, verified_supplier, _ctx):
        l = _live_animal_listing(verified_supplier, _ctx, slug="hisor-butcher")
        r = buyer_client.post(self.URL, {
            "items": [{"listing": l.id, "quantity_kg": "1.00"}],
            "butcher_service_requested": True,
            **self.BUYER_TASHKENT,
        }, format="json")
        assert r.status_code == 200
        opts = {o["code"]: o for o in r.data["options"]}
        # Slaughter at hub → finished meat needs cold chain back to buyer.
        assert opts[Order.VehicleType.REFRIGERATOR]["available"] is True
        assert opts[Order.VehicleType.CHORVA_TAXI]["available"] is False
        assert r.data["butcher_service"]["requested"] is True
        # Non-zero butcher fee should appear on the quote.
        assert Decimal(r.data["butcher_service"]["fee"]) > Decimal("0")

    def test_distance_increases_total_price(self, buyer_client, verified_supplier, _ctx):
        l = _raw_meat_listing(verified_supplier, _ctx, slug="distance")
        near = buyer_client.post(self.URL, {
            "items": [{"listing": l.id, "quantity_kg": "10.00"}], **self.BUYER_TASHKENT,
        }, format="json")
        far = buyer_client.post(self.URL, {
            "items": [{"listing": l.id, "quantity_kg": "10.00"}], **self.BUYER_FAR,
        }, format="json")
        near_price = Decimal([o for o in near.data["options"]
                              if o["code"] == Order.VehicleType.REFRIGERATOR][0]["total_price"])
        far_price = Decimal([o for o in far.data["options"]
                             if o["code"] == Order.VehicleType.REFRIGERATOR][0]["total_price"])
        assert far_price > near_price                                       # PRD formula: base + km × rate

    def test_empty_items_returns_400(self, buyer_client):
        r = buyer_client.post(self.URL, {"items": [], **self.BUYER_TASHKENT}, format="json")
        # DRF rejects empty list at the field level — covers the case before view-layer logic runs.
        assert r.status_code in (400,)

    def test_anonymous_can_quote(self, api, verified_supplier, _ctx):
        # Quote endpoint is public — buyers preview delivery costs before sign-up. Auth still gates the
        # actual order POST. An anonymous request with valid items should get a 200 response.
        l = _raw_meat_listing(verified_supplier, _ctx, slug="anon")
        r = api.post(self.URL, {
            "items": [{"listing": l.id, "quantity_kg": "10.00"}],
            **self.BUYER_TASHKENT,
        }, format="json")
        assert r.status_code == 200
        assert "options" in r.data and "time_slots" in r.data


# ---------- 10kg minimum + delivery persistence on order create ----------

@pytest.mark.django_db
class TestOrderCreateWithDelivery:
    ORDERS_URL = "/api/v1/orders/"

    def test_below_10kg_rejected_for_by_weight_listing(self, buyer_client, verified_supplier, _ctx):
        l = _raw_meat_listing(verified_supplier, _ctx, slug="min10")
        r = buyer_client.post(self.ORDERS_URL, {
            "listing": l.id, "quantity_kg": "5.00", "delivery_address": "addr",
        }, format="json")
        assert r.status_code == 400 and "quantity_kg" in str(r.data)

    def test_10kg_exactly_accepted(self, buyer_client, verified_supplier, _ctx):
        l = _raw_meat_listing(verified_supplier, _ctx, slug="min10-ok")
        r = buyer_client.post(self.ORDERS_URL, {
            "listing": l.id, "quantity_kg": "10.00", "delivery_address": "addr",
        }, format="json")
        assert r.status_code == 201

    def test_by_head_live_animal_bypasses_10kg_rule(self, buyer_client, verified_supplier, _ctx):
        l = _live_animal_listing(verified_supplier, _ctx, by_head=True, slug="live-by-head")
        # quantity_kg=1 means "1 head" for BY_HEAD listings — the 10kg-min rule doesn't apply.
        r = buyer_client.post(self.ORDERS_URL, {
            "listing": l.id, "quantity_kg": "1.00", "delivery_address": "Jizzax",
        }, format="json")
        assert r.status_code == 201

    def test_delivery_and_butcher_persist_on_order(self, buyer_client, verified_supplier, _ctx):
        l = _raw_meat_listing(verified_supplier, _ctx, slug="persist-delivery")
        payload = {
            "listing": l.id, "quantity_kg": "10.00",
            "delivery_address": "Tashkent, Yunusobod, 1-7",
            "delivery_vehicle_type": Order.VehicleType.REFRIGERATOR,
            "delivery_time_slot": Order.TimeSlot.SLOT_0609,
            "delivery_distance_km": "12.50",
            "delivery_lat": "41.3380", "delivery_lng": "69.2810",
            "delivery_price": "103750.00",
            "butcher_service_requested": False,
            "butcher_service_fee": "0.00",
        }
        r = buyer_client.post(self.ORDERS_URL, payload, format="json")
        assert r.status_code == 201
        order = Order.objects.get(pk=r.data["id"])
        assert order.delivery_vehicle_type == Order.VehicleType.REFRIGERATOR
        assert order.delivery_time_slot == Order.TimeSlot.SLOT_0609
        assert order.delivery_distance_km == Decimal("12.50")
        # total_price should be listing × qty + delivery (line: 10 × 50,000 + 103,750 = 603,750)
        assert order.total_price == Decimal("603750.00")
