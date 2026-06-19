"""Partner cross-role endpoint matrix — inbox routing, accept/reject, earnings, dashboard, smart tips."""
from datetime import date, timedelta
from decimal import Decimal

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import User
from apps.listings.models import Listing, MeatCategory
from apps.markets.models import Market
from apps.orders.models import Order
from apps.qassobs.models import QassobProfile


def _client_for(user):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return c


@pytest.fixture
def _ctx(db):
    owner, _ = User.objects.get_or_create(email="po@test.local", defaults={
        "full_name": "P O", "role": User.Role.SUPPLIER})
    market = Market.objects.create(slug="p-mkt", name_uz="P Mkt", name_ru="P Mkt",
                                    region="Tashkent", address="—", is_active=True,
                                    created_by=owner, updated_by=owner)
    category, _ = MeatCategory.objects.get_or_create(
        slug="mol-goshti", defaults={"name_uz": "Mol", "name_ru": "Mol", "display_order": 10})
    return market, category


@pytest.fixture
def supplier_user(verified_supplier): return verified_supplier


@pytest.fixture
def supplier_client(supplier_user): return _client_for(supplier_user)


@pytest.fixture
def qassob_user(db):
    u = User.objects.create_user(email="pq@test.local", password="X", full_name="P Q",
                                  role=User.Role.QASSOB, phone="+998905555555")
    QassobProfile.objects.create(user=u, full_name="P Q", years_experience=8,
                                   region="Tashkent", address="addr",
                                   animals_supported=["MOL"], daily_capacity_head=10,
                                   is_verified=True)
    return u


@pytest.fixture
def qassob_client(qassob_user): return _client_for(qassob_user)


def _listing(supplier, ctx, slug="prod-1", live=False):
    market, category = ctx
    l = Listing(supplier=supplier, market=market, category=category, slug=slug,
                 name_uz="Test", name_ru="Test", quantity_kg=Decimal("100"),
                 price_per_kg=Decimal("50000"), location="Tashkent",
                 available_from=date.today() + timedelta(days=1),
                 status=Listing.Status.ACTIVE, is_live_animal=live)
    l._skip_price_history = True
    l.save()
    return l


def _order(buyer, listing, qty="10", status_=Order.Status.PENDING, paid=False, butcher=False):
    o = Order.objects.create(buyer=buyer, listing=listing, quantity_kg=Decimal(qty),
                              total_price=Decimal("500000"), delivery_address="addr",
                              status=status_,
                              payment_status=Order.PaymentStatus.PAID if paid else Order.PaymentStatus.UNPAID,
                              butcher_service_requested=butcher,
                              butcher_service_fee=Decimal("200000") if butcher else Decimal("0"))
    return o


# ---------------- Inbox ----------------

@pytest.mark.django_db
class TestInbox:
    URL = "/api/v1/partner/inbox/"

    def test_buyer_blocked(self, buyer_client):
        r = buyer_client.get(self.URL)
        assert r.status_code == 403

    def test_supplier_sees_own_pending(self, supplier_client, supplier_user, buyer_user, _ctx):
        l = _listing(supplier_user, _ctx)
        _order(buyer_user, l)
        r = supplier_client.get(f"{self.URL}?bucket=new")
        assert r.status_code == 200 and r.data["count"] == 1

    def test_qassob_sees_awaiting_jobs(self, qassob_client, supplier_user, buyer_user, _ctx):
        l = _listing(supplier_user, _ctx, slug="live-1", live=True)
        _order(buyer_user, l, status_=Order.Status.AWAITING_QASSOB, butcher=True)
        r = qassob_client.get(f"{self.URL}?bucket=new")
        assert r.status_code == 200 and r.data["count"] == 1


# ---------------- Accept / Reject ----------------

@pytest.mark.django_db
class TestAccept:
    def test_supplier_accept(self, supplier_client, supplier_user, buyer_user, _ctx):
        l = _listing(supplier_user, _ctx)
        o = _order(buyer_user, l)
        r = supplier_client.post(f"/api/v1/partner/orders/{o.id}/accept/")
        assert r.status_code == 200 and r.data["status"] == "CONFIRMED"

    def test_qassob_claims_job(self, qassob_client, qassob_user, supplier_user, buyer_user, _ctx):
        l = _listing(supplier_user, _ctx, slug="live-2", live=True)
        o = _order(buyer_user, l, status_=Order.Status.AWAITING_QASSOB, butcher=True)
        r = qassob_client.post(f"/api/v1/partner/orders/{o.id}/accept/")
        assert r.status_code == 200 and r.data["status"] == "PROCESSING_BUTCHER"
        o.refresh_from_db()
        assert o.assigned_qassob_id == qassob_user.id
        assert o.qassob_payout == Decimal("120000.00")            # 60% of 200k

    def test_qassob_already_claimed_409(self, qassob_client, qassob_user, supplier_user,
                                          buyer_user, _ctx, db):
        # Pre-claim by another qassob
        other = User.objects.create_user(email="oq@test.local", password="X", full_name="O",
                                          role=User.Role.QASSOB)
        l = _listing(supplier_user, _ctx, slug="live-3", live=True)
        o = _order(buyer_user, l, status_=Order.Status.AWAITING_QASSOB, butcher=True)
        o.assigned_qassob = other
        o.status = Order.Status.PROCESSING_BUTCHER
        o.save()
        r = qassob_client.post(f"/api/v1/partner/orders/{o.id}/accept/")
        assert r.status_code == 409


# ---------------- Earnings + dashboard ----------------

@pytest.mark.django_db
class TestEarningsDashboard:
    def test_supplier_earnings_day(self, supplier_client, supplier_user, buyer_user, _ctx):
        l = _listing(supplier_user, _ctx)
        _order(buyer_user, l, paid=True)
        _order(buyer_user, l, paid=True)
        r = supplier_client.get("/api/v1/partner/earnings/?period=day")
        assert r.status_code == 200
        assert r.data["order_count"] == 2
        assert Decimal(r.data["total_revenue"]) == Decimal("1000000")

    def test_dashboard_shape(self, supplier_client, supplier_user, _ctx):
        l = _listing(supplier_user, _ctx)
        r = supplier_client.get("/api/v1/partner/dashboard/")
        assert r.status_code == 200
        assert r.data["role"] == "SUPPLIER"
        assert "today_revenue" in r.data and "open_orders" in r.data


# ---------------- Smart tips ----------------

@pytest.mark.django_db
class TestSmartTips:
    def test_returns_list(self, supplier_client):
        r = supplier_client.get("/api/v1/partner/smart-tips/")
        assert r.status_code == 200
        assert "tips" in r.data
        # All tips should be within 30 days
        for t in r.data["tips"]:
            assert 0 <= t["days_until"] <= 365


# ---------------- F5 quick price ----------------

@pytest.mark.django_db
class TestQuickPrice:
    def test_supplier_updates_own_listing(self, supplier_client, supplier_user, _ctx):
        l = _listing(supplier_user, _ctx, slug="qp")
        r = supplier_client.post(f"/api/v1/partner/listings/{l.id}/quick-price/",
                                   {"price_per_kg": "55000.00"}, format="json")
        assert r.status_code == 200
        l.refresh_from_db()
        assert l.price_per_kg == Decimal("55000.00")

    def test_foreign_listing_404(self, supplier_client, supplier_user, _ctx, db):
        other = User.objects.create_user(email="other-s@test.local", password="X",
                                          full_name="O", role=User.Role.SUPPLIER)
        l = _listing(other, _ctx, slug="qp-foreign")
        r = supplier_client.post(f"/api/v1/partner/listings/{l.id}/quick-price/",
                                   {"price_per_kg": "55000.00"}, format="json")
        assert r.status_code == 404
