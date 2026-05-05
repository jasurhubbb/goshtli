"""Listing endpoint tests — public browse, supplier CRUD, ownership guards, filters, delete-with-orders protection.

These mirror the live curl tests from Phase 2.6's coverage matrix; ports them into pytest so they run automatically on every change.
"""
import pytest
from datetime import date, timedelta

from apps.listings.models import Listing


def _make_listing(supplier, **overrides):
    """Test helper — creates a listing with sensible defaults; tests override only the fields they care about."""
    return Listing.objects.create(
        supplier=supplier,
        title=overrides.get("title", "Premium Beef"),
        meat_type=overrides.get("meat_type", Listing.MeatType.BEEF),
        quantity_kg=overrides.get("quantity_kg", "100.00"),
        price_per_kg=overrides.get("price_per_kg", "45000.00"),
        location=overrides.get("location", "Tashkent"),
        available_from=overrides.get("available_from", date.today() + timedelta(days=1)),
        description=overrides.get("description", ""),
        status=overrides.get("status", Listing.Status.ACTIVE))


@pytest.mark.django_db
class TestPublicBrowse:
    """GET /api/v1/listings/ — anonymous-readable, hides INACTIVE/SOLD_OUT by default."""

    def test_anonymous_can_browse(self, api):
        assert api.get("/api/v1/listings/").status_code == 200

    def test_default_browse_hides_inactive(self, api, verified_supplier):
        _make_listing(verified_supplier, title="Active one")
        _make_listing(verified_supplier, title="Hidden inactive", status=Listing.Status.INACTIVE)
        r = api.get("/api/v1/listings/")
        titles = [x["title"] for x in r.data["results"]]
        assert "Active one" in titles and "Hidden inactive" not in titles

    def test_explicit_status_filter_includes_non_active(self, api, verified_supplier):
        _make_listing(verified_supplier, title="Inactive one", status=Listing.Status.INACTIVE)
        r = api.get("/api/v1/listings/?status=INACTIVE")
        assert r.status_code == 200 and len(r.data["results"]) == 1

    def test_filter_by_meat_type(self, api, verified_supplier):
        _make_listing(verified_supplier, title="Beef", meat_type=Listing.MeatType.BEEF)
        _make_listing(verified_supplier, title="Mutton", meat_type=Listing.MeatType.MUTTON)
        r = api.get("/api/v1/listings/?meat_type=MUTTON")
        assert {x["title"] for x in r.data["results"]} == {"Mutton"}

    def test_filter_by_price_range(self, api, verified_supplier):
        _make_listing(verified_supplier, title="Cheap", price_per_kg="10000.00")
        _make_listing(verified_supplier, title="Pricey", price_per_kg="80000.00")
        r = api.get("/api/v1/listings/?price_min=20000")
        assert {x["title"] for x in r.data["results"]} == {"Pricey"}
        r = api.get("/api/v1/listings/?price_max=20000")
        assert {x["title"] for x in r.data["results"]} == {"Cheap"}

    def test_filter_by_location_icontains(self, api, verified_supplier):
        _make_listing(verified_supplier, title="A", location="Samarkand")
        _make_listing(verified_supplier, title="B", location="Tashkent")
        r = api.get("/api/v1/listings/?location=samar")
        assert {x["title"] for x in r.data["results"]} == {"A"}

    def test_search_matches_description(self, api, verified_supplier):
        _make_listing(verified_supplier, title="A", description="Grass-fed Hereford")
        _make_listing(verified_supplier, title="B")
        r = api.get("/api/v1/listings/?search=hereford")
        assert {x["title"] for x in r.data["results"]} == {"A"}

    def test_ordering_by_price_ascending(self, api, verified_supplier):
        _make_listing(verified_supplier, title="Pricey", price_per_kg="60000.00")
        _make_listing(verified_supplier, title="Cheap", price_per_kg="10000.00")
        r = api.get("/api/v1/listings/?ordering=price_per_kg")
        assert [x["title"] for x in r.data["results"]] == ["Cheap", "Pricey"]


@pytest.mark.django_db
class TestSupplierCreate:
    """POST /api/v1/listings/ — verified-supplier-only."""

    payload = {"title": "New", "meat_type": "BEEF", "quantity_kg": "50.00",
               "price_per_kg": "30000.00", "location": "Tashkent", "available_from": str(date.today() + timedelta(days=1))}

    def test_unverified_supplier_blocked(self, supplier_client):
        r = supplier_client.post("/api/v1/listings/", self.payload, format="json")
        assert r.status_code == 403

    def test_buyer_blocked(self, buyer_client):
        r = buyer_client.post("/api/v1/listings/", self.payload, format="json")
        assert r.status_code == 403

    def test_anonymous_blocked(self, api):
        r = api.post("/api/v1/listings/", self.payload, format="json")
        assert r.status_code == 401 or r.status_code == 403

    def test_verified_supplier_creates(self, verified_supplier_client):
        r = verified_supplier_client.post("/api/v1/listings/", self.payload, format="json")
        assert r.status_code == 201 and r.data["status"] == "ACTIVE"


@pytest.mark.django_db
class TestSupplierMutate:
    """PATCH/DELETE on /api/v1/listings/{id}/ — owner-only."""

    def test_owner_can_patch(self, verified_supplier_client, verified_supplier):
        l = _make_listing(verified_supplier)
        r = verified_supplier_client.patch(f"/api/v1/listings/{l.pk}/",
                                           {"price_per_kg": "55000.00"}, format="json")
        assert r.status_code == 200 and r.data["price_per_kg"] == "55000.00"

    def test_non_owner_cannot_patch(self, db, verified_supplier_client):
        # Create a SECOND supplier user — verified_supplier_client is logged in as a different supplier
        from apps.accounts.models import User
        other = User.objects.create_user(email="other@supp.local", password="StrongPass123!",
                                         full_name="Other", role=User.Role.SUPPLIER)
        other_listing = _make_listing(other)
        r = verified_supplier_client.patch(f"/api/v1/listings/{other_listing.pk}/",
                                           {"price_per_kg": "1.00"}, format="json")
        assert r.status_code == 403

    def test_delete_without_orders_succeeds(self, verified_supplier_client, verified_supplier):
        l = _make_listing(verified_supplier)
        assert verified_supplier_client.delete(f"/api/v1/listings/{l.pk}/").status_code == 204

    def test_delete_with_orders_blocked_with_friendly_message(self, verified_supplier_client, verified_supplier, buyer_user):
        from apps.orders.models import Order
        l = _make_listing(verified_supplier)
        Order.objects.create(buyer=buyer_user, listing=l, quantity_kg="1.00",
                             total_price="45000.00", delivery_address="addr")
        r = verified_supplier_client.delete(f"/api/v1/listings/{l.pk}/")
        # Backend refuses delete and tells supplier to set INACTIVE instead
        assert r.status_code == 403 and "INACTIVE" in str(r.data)


@pytest.mark.django_db
class TestMyListings:
    """/api/v1/listings/my/ — verified-supplier-only, returns own listings across all statuses."""

    def test_verified_supplier_sees_own(self, verified_supplier_client, verified_supplier):
        _make_listing(verified_supplier, title="Mine 1")
        _make_listing(verified_supplier, title="Mine 2", status=Listing.Status.INACTIVE)
        r = verified_supplier_client.get("/api/v1/listings/my/")
        assert r.status_code == 200 and r.data["count"] == 2

    def test_unverified_supplier_blocked(self, supplier_client):
        assert supplier_client.get("/api/v1/listings/my/").status_code == 403

    def test_buyer_blocked(self, buyer_client):
        assert buyer_client.get("/api/v1/listings/my/").status_code == 403
