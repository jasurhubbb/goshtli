"""Listing endpoint tests — public browse, supplier CRUD, ownership guards, filters, delete-with-orders protection.

v3.1 catalog overhaul: tests now use the multi-tenant (Market) + bilingual (name_uz/name_ru) schema. The Listing
factory takes a market + category and seeds both name languages. Filter assertions hit the new query params
(?category=, ?market=, ?region=) instead of the dropped meat_type.
"""
import pytest
from datetime import date, timedelta

from apps.listings.models import Listing


def _make_listing(supplier, market, category, **overrides):
    """Test helper — creates a Listing with sensible defaults; tests override only the fields they care about.

    The market + category fixtures are passed explicitly so the test reads what it depends on at a glance.
    Sets _skip_price_history so factory creates don't pollute PriceHistory in tests that aren't about it.
    """
    listing = Listing(
        supplier=supplier,
        market=overrides.get("market", market),
        category=overrides.get("category", category),
        slug=overrides.get("slug", overrides.get("name_uz", "test-product").lower().replace(" ", "-")),
        name_uz=overrides.get("name_uz", "Test Product"),
        name_ru=overrides.get("name_ru", overrides.get("name_uz", "Test Product")),
        description_uz=overrides.get("description_uz", ""),
        description_ru=overrides.get("description_ru", ""),
        quantity_kg=overrides.get("quantity_kg", "100.00"),
        price_per_kg=overrides.get("price_per_kg", "45000.00"),
        location=overrides.get("location", "Tashkent"),
        available_from=overrides.get("available_from", date.today() + timedelta(days=1)),
        status=overrides.get("status", Listing.Status.ACTIVE),
    )
    listing._skip_price_history = True
    listing.save()
    return listing


@pytest.mark.django_db
class TestPublicBrowse:
    """GET /api/v1/listings/ — anonymous-readable, hides ARCHIVED/OUT_OF_STOCK by default."""

    def test_anonymous_can_browse(self, api):
        assert api.get("/api/v1/listings/").status_code == 200

    def test_default_browse_hides_archived(self, api, verified_supplier, market, meat_category_beef):
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Active one", slug="active")
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Hidden archived",
                      slug="hidden", status=Listing.Status.ARCHIVED)
        r = api.get("/api/v1/listings/")
        names = [x["name_uz"] for x in r.data["results"]]
        assert "Active one" in names and "Hidden archived" not in names

    def test_explicit_status_filter_includes_non_active(self, api, verified_supplier, market, meat_category_beef):
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Archived one",
                      slug="arch", status=Listing.Status.ARCHIVED)
        r = api.get("/api/v1/listings/?status=ARCHIVED")
        assert r.status_code == 200 and len(r.data["results"]) == 1

    def test_filter_by_category(self, api, verified_supplier, market, meat_category_beef, meat_category_mutton):
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Beef", slug="b")
        _make_listing(verified_supplier, market, meat_category_mutton, name_uz="Mutton", slug="m")
        r = api.get("/api/v1/listings/?category=qoy-goshti")
        assert {x["name_uz"] for x in r.data["results"]} == {"Mutton"}

    def test_filter_by_market(self, api, verified_supplier, market, meat_category_beef):
        from apps.markets.models import Market
        other = Market.objects.create(slug="other", name_uz="Other", name_ru="Другой",
                                      region="Samarkand", address="—", is_active=True)
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="In test", slug="t")
        _make_listing(verified_supplier, other, meat_category_beef, name_uz="In other", slug="o")
        r = api.get("/api/v1/listings/?market=test-market")
        assert {x["name_uz"] for x in r.data["results"]} == {"In test"}

    def test_filter_by_price_range(self, api, verified_supplier, market, meat_category_beef):
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Cheap", slug="c", price_per_kg="10000.00")
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Pricey", slug="p", price_per_kg="80000.00")
        r = api.get("/api/v1/listings/?price_min=20000")
        assert {x["name_uz"] for x in r.data["results"]} == {"Pricey"}
        r = api.get("/api/v1/listings/?price_max=20000")
        assert {x["name_uz"] for x in r.data["results"]} == {"Cheap"}

    def test_q_param_searches_both_languages(self, api, verified_supplier, market, meat_category_beef):
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Mol go'shti premium",
                      name_ru="Премиум говядина", slug="prem")
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Tovuq filesi",
                      name_ru="Куриное филе", slug="fil")
        # Russian-only term matches via name_ru
        r = api.get("/api/v1/listings/?q=Премиум")
        assert {x["name_uz"] for x in r.data["results"]} == {"Mol go'shti premium"}
        # Uzbek-only term matches via name_uz
        r = api.get("/api/v1/listings/?q=filesi")
        assert {x["name_uz"] for x in r.data["results"]} == {"Tovuq filesi"}

    def test_ordering_by_price_ascending(self, api, verified_supplier, market, meat_category_beef):
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Pricey", slug="p", price_per_kg="60000.00")
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Cheap", slug="c", price_per_kg="10000.00")
        r = api.get("/api/v1/listings/?ordering=price_per_kg")
        assert [x["name_uz"] for x in r.data["results"]] == ["Cheap", "Pricey"]


@pytest.mark.django_db
class TestSupplierCreate:
    """POST /api/v1/listings/ — verified-supplier-only."""

    def _payload(self, market, category):
        return {
            "market_id": market.pk, "category_id": category.pk,
            "name_uz": "New", "name_ru": "Новый",
            "quantity_kg": "50.00", "price_per_kg": "30000.00",
            "location": "Tashkent",
            "available_from": str(date.today() + timedelta(days=1)),
        }

    def test_unverified_supplier_blocked(self, supplier_client, market, meat_category_beef):
        r = supplier_client.post("/api/v1/listings/", self._payload(market, meat_category_beef), format="json")
        assert r.status_code == 403

    def test_buyer_blocked(self, buyer_client, market, meat_category_beef):
        r = buyer_client.post("/api/v1/listings/", self._payload(market, meat_category_beef), format="json")
        assert r.status_code == 403

    def test_anonymous_blocked(self, api, market, meat_category_beef):
        r = api.post("/api/v1/listings/", self._payload(market, meat_category_beef), format="json")
        assert r.status_code in (401, 403)

    def test_verified_supplier_creates(self, verified_supplier_client, market, meat_category_beef):
        r = verified_supplier_client.post("/api/v1/listings/",
                                          self._payload(market, meat_category_beef), format="json")
        assert r.status_code == 201, r.data
        assert r.data["status"] == "ACTIVE"
        assert r.data["name_uz"] == "New"


@pytest.mark.django_db
class TestSupplierMutate:
    """PATCH/DELETE on /api/v1/listings/{id}/ — owner-only."""

    def test_owner_can_patch(self, verified_supplier_client, verified_supplier, market, meat_category_beef):
        l = _make_listing(verified_supplier, market, meat_category_beef, name_uz="X", slug="x")
        r = verified_supplier_client.patch(f"/api/v1/listings/{l.pk}/",
                                           {"price_per_kg": "55000.00"}, format="json")
        assert r.status_code == 200, r.data
        assert r.data["price_per_kg"] == "55000.00"

    def test_non_owner_cannot_patch(self, db, verified_supplier_client, market, meat_category_beef):
        # Second supplier user — verified_supplier_client is logged in as a different one
        from apps.accounts.models import User
        other = User.objects.create_user(email="other@supp.local", password="StrongPass123!",
                                         full_name="Other", role=User.Role.SUPPLIER)
        other_listing = _make_listing(other, market, meat_category_beef, name_uz="Y", slug="y")
        r = verified_supplier_client.patch(f"/api/v1/listings/{other_listing.pk}/",
                                           {"price_per_kg": "1.00"}, format="json")
        assert r.status_code == 403

    def test_delete_without_orders_succeeds(self, verified_supplier_client, verified_supplier,
                                            market, meat_category_beef):
        l = _make_listing(verified_supplier, market, meat_category_beef, name_uz="Z", slug="z")
        assert verified_supplier_client.delete(f"/api/v1/listings/{l.pk}/").status_code == 204

    def test_delete_with_orders_blocked_with_friendly_message(self, verified_supplier_client, verified_supplier,
                                                              buyer_user, market, meat_category_beef):
        from apps.orders.models import Order
        l = _make_listing(verified_supplier, market, meat_category_beef, name_uz="W", slug="w")
        Order.objects.create(buyer=buyer_user, listing=l, quantity_kg="1.00",
                             total_price="45000.00", delivery_address="addr")
        r = verified_supplier_client.delete(f"/api/v1/listings/{l.pk}/")
        # Backend refuses delete and tells supplier to set ARCHIVED instead
        assert r.status_code == 403 and "ARCHIVED" in str(r.data)


@pytest.mark.django_db
class TestMyListings:
    """/api/v1/listings/my/ — verified-supplier-only, returns own listings across all statuses."""

    def test_verified_supplier_sees_own(self, verified_supplier_client, verified_supplier,
                                        market, meat_category_beef):
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Mine 1", slug="m1")
        _make_listing(verified_supplier, market, meat_category_beef, name_uz="Mine 2", slug="m2",
                      status=Listing.Status.ARCHIVED)
        r = verified_supplier_client.get("/api/v1/listings/my/")
        assert r.status_code == 200 and r.data["count"] == 2

    def test_unverified_supplier_blocked(self, supplier_client):
        assert supplier_client.get("/api/v1/listings/my/").status_code == 403

    def test_buyer_blocked(self, buyer_client):
        assert buyer_client.get("/api/v1/listings/my/").status_code == 403
