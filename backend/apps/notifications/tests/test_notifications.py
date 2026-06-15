"""Notification tests — auto-create on domain events, list scoping, mark-read, unread-count.

v3.1 catalog overhaul: the listing helper now needs a Market + MeatCategory to satisfy the new FK constraints.
We bundle them into one fixture (`_ctx`) the tests pull in by name."""
import pytest
from datetime import date, timedelta

from apps.listings.models import Listing, MeatCategory
from apps.markets.models import Market
from apps.notifications.models import Notification


@pytest.fixture
def _ctx(db):
    """Market + MeatCategory the notification tests' Listing factory anchors to.

    Uses its own dedicated owner user — NOT verified_supplier — so the fixture doesn't have the side effect of
    flipping is_verified=True on the shared supplier@test.local. Same isolation pattern as conftest.market.
    """
    from apps.accounts.models import User
    owner, _ = User.objects.get_or_create(email="notif-market-owner@test.local", defaults={
        "full_name": "Notif Market Owner", "role": User.Role.SUPPLIER})
    market = Market.objects.create(slug="notif-market", name_uz="Notif Market", name_ru="Уведомления Рынок",
                                   region="Tashkent", address="—", is_active=True,
                                   created_by=owner, updated_by=owner)
    category, _ = MeatCategory.objects.get_or_create(
        slug="mol-goshti", defaults={"name_uz": "Mol go'shti", "name_ru": "Говядина", "display_order": 10})
    return market, category


def _listing(supplier, ctx):
    """Compact Listing factory for notification tests — minimum fields, sane defaults."""
    market, category = ctx
    l = Listing(
        supplier=supplier, market=market, category=category,
        slug="t", name_uz="t", name_ru="t",
        quantity_kg="100.00", price_per_kg="50000.00", location="x",
        available_from=date.today() + timedelta(days=1),
    )
    l._skip_price_history = True
    l.save()
    return l


@pytest.mark.django_db
class TestAutoCreate:
    """Signals (notifications/signals.py) should auto-create notifications on supplier verification + order events."""

    def test_supplier_verification_creates_notification(self, supplier_user):
        # Initially no notifications
        assert Notification.objects.filter(user=supplier_user).count() == 0
        # Flip is_verified = True → signal fires
        p = supplier_user.supplier_profile; p.is_verified = True; p.save()
        assert Notification.objects.filter(user=supplier_user, kind=Notification.Kind.SUPPLIER_VERIFIED).count() == 1

    def test_unverify_does_not_re_notify(self, verified_supplier):
        Notification.objects.filter(user=verified_supplier).delete()  # clear the auto-fired one
        p = verified_supplier.supplier_profile; p.is_verified = False; p.save()
        # Going True→False should NOT create a notification
        assert Notification.objects.filter(user=verified_supplier, kind=Notification.Kind.SUPPLIER_VERIFIED).count() == 0

    def test_new_order_notifies_supplier(self, buyer_client, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx)
        Notification.objects.filter(user=verified_supplier).delete()  # ignore the verification one
        buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                               "delivery_address": "addr"}, format="json")
        assert Notification.objects.filter(user=verified_supplier, kind=Notification.Kind.ORDER_PLACED).count() == 1

    def test_status_change_notifies_buyer(self, buyer_client, verified_supplier_client, verified_supplier, buyer_user, _ctx):
        l = _listing(verified_supplier, _ctx)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        Notification.objects.filter(user=buyer_user).delete()
        verified_supplier_client.post(f"/api/v1/orders/supplier/{oid}/status/",
                                      {"status": "CONFIRMED"}, format="json")
        assert Notification.objects.filter(user=buyer_user, kind=Notification.Kind.ORDER_STATUS_CHANGED).count() == 1

    def test_cancellation_notifies_both_parties(self, buyer_client, buyer_user, verified_supplier, _ctx):
        l = _listing(verified_supplier, _ctx)
        oid = buyer_client.post("/api/v1/orders/", {"listing": l.pk, "quantity_kg": "10.00",
                                                     "delivery_address": "addr"}, format="json").data["id"]
        Notification.objects.all().delete()
        buyer_client.post(f"/api/v1/orders/{oid}/cancel/")
        # Both buyer and supplier should get a CANCELLED notification — UI dedupes via per-user feed scoping
        assert Notification.objects.filter(user=buyer_user, kind=Notification.Kind.ORDER_CANCELLED).count() == 1
        assert Notification.objects.filter(user=verified_supplier, kind=Notification.Kind.ORDER_CANCELLED).count() == 1


@pytest.mark.django_db
class TestNotificationEndpoints:
    """List, unread-count, mark-read, mark-all-read."""

    def test_list_only_returns_own_notifications(self, buyer_client, buyer_user, verified_supplier):
        # Create one for the buyer and one for the supplier — list should hide the supplier's from the buyer
        Notification.objects.create(user=buyer_user, kind=Notification.Kind.OTHER, title="mine")
        Notification.objects.create(user=verified_supplier, kind=Notification.Kind.OTHER, title="not mine")
        r = buyer_client.get("/api/v1/notifications/")
        titles = [n["title"] for n in r.data["results"]]
        assert "mine" in titles and "not mine" not in titles

    def test_unread_count(self, buyer_client, buyer_user):
        Notification.objects.create(user=buyer_user, kind=Notification.Kind.OTHER, title="a")
        Notification.objects.create(user=buyer_user, kind=Notification.Kind.OTHER, title="b", is_read=True)
        r = buyer_client.get("/api/v1/notifications/unread-count/")
        assert r.status_code == 200 and r.data["unread"] == 1

    def test_mark_read_flips_flag(self, buyer_client, buyer_user):
        n = Notification.objects.create(user=buyer_user, kind=Notification.Kind.OTHER, title="a")
        r = buyer_client.post(f"/api/v1/notifications/{n.pk}/read/")
        n.refresh_from_db()
        assert r.status_code == 200 and n.is_read is True

    def test_mark_read_on_other_users_notification_returns_404(self, buyer_client, verified_supplier):
        # Caller (buyer) should NOT be able to flip a notification belonging to another user
        n = Notification.objects.create(user=verified_supplier, kind=Notification.Kind.OTHER, title="theirs")
        r = buyer_client.post(f"/api/v1/notifications/{n.pk}/read/")
        n.refresh_from_db()
        assert r.status_code == 404 and n.is_read is False

    def test_mark_all_read_only_affects_caller(self, buyer_client, buyer_user, verified_supplier):
        Notification.objects.create(user=buyer_user, kind=Notification.Kind.OTHER, title="mine")
        their = Notification.objects.create(user=verified_supplier, kind=Notification.Kind.OTHER, title="theirs")
        r = buyer_client.post("/api/v1/notifications/read-all/")
        their.refresh_from_db()
        assert r.status_code == 204 and their.is_read is False  # other user's not affected
        assert Notification.objects.filter(user=buyer_user, is_read=False).count() == 0

    def test_anonymous_blocked(self, api):
        assert api.get("/api/v1/notifications/").status_code == 401
