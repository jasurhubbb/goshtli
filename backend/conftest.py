"""Shared pytest fixtures — provides admin/supplier/buyer users + an authenticated APIClient per role.

Why fixtures here (project root) rather than per-app conftest: the same fixtures are reused across every app's
test module, so co-locating them here means less duplication. Tests pull what they need by argument name.
"""
import pytest
from django.conf import settings
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.suppliers.models import SupplierProfile


@pytest.fixture(autouse=True)
def _celery_eager_mode():
    """Run every test with Celery in eager mode so tasks fire inline (no Redis broker required).

    `autouse=True` applies to every test — keeps the test suite hermetic. If a future test wants to assert
    that a task was DEFERRED (not run), it can override this fixture locally or use celery's apply_async chain.
    """
    settings.CELERY_TASK_ALWAYS_EAGER = True
    settings.CELERY_TASK_EAGER_PROPAGATES = True
    yield


@pytest.fixture
def api():
    """Plain unauthenticated APIClient — for register/login flows or anonymous endpoint checks."""
    return APIClient()


@pytest.fixture
def buyer_user(db):
    """Persistent buyer user — pytest-django's `db` fixture wraps the test in a transaction so it's rolled back after."""
    return User.objects.create_user(email="buyer@test.local", password="StrongPass123!",
                                    full_name="Test Buyer", role=User.Role.BUYER)


@pytest.fixture
def supplier_user(db):
    """Unverified supplier — listing creation should be blocked until is_verified flips True."""
    return User.objects.create_user(email="supplier@test.local", password="StrongPass123!",
                                    full_name="Test Supplier", role=User.Role.SUPPLIER)


@pytest.fixture
def verified_supplier(supplier_user):
    """Supplier with is_verified=True — can create listings. Profile gets auto-created via signal at user save time."""
    profile = supplier_user.supplier_profile
    profile.is_verified = True
    profile.save()
    return supplier_user


@pytest.fixture
def admin_user(db):
    return User.objects.create_superuser(email="admin@test.local", password="AdminPass123!", full_name="Admin")


# ---------- Catalog fixtures (v3.1 schema) ----------

@pytest.fixture
def meat_category_beef(db):
    """Seed the Mol go'shti category for tests. Mirrors what migration 0004 inserts in real DBs."""
    from apps.listings.models import MeatCategory
    cat, _ = MeatCategory.objects.get_or_create(
        slug="mol-goshti", defaults={"name_uz": "Mol go'shti", "name_ru": "Говядина", "display_order": 10})
    return cat


@pytest.fixture
def meat_category_mutton(db):
    from apps.listings.models import MeatCategory
    cat, _ = MeatCategory.objects.get_or_create(
        slug="qoy-goshti", defaults={"name_uz": "Qo'y go'shti", "name_ru": "Баранина", "display_order": 20})
    return cat


@pytest.fixture
def market(db):
    """A baseline Market — most listing tests need one to attach products to.

    Important: we deliberately do NOT depend on `verified_supplier` here. Going through that fixture would
    flip is_verified=True on the shared supplier@test.local user — which then breaks the
    'unverified-supplier blocked from POST' tests that need that same user to still be UNverified.
    Instead the market has its own owner user, fully isolated from the supplier_client/verified_supplier chain.
    """
    from apps.markets.models import Market
    owner, _ = User.objects.get_or_create(email="market-owner@test.local", defaults={
        "full_name": "Market Owner", "role": User.Role.SUPPLIER})
    return Market.objects.create(
        slug="test-market", name_uz="Test bozori", name_ru="Тестовый рынок",
        region="Tashkent", address="—", is_active=True,
        created_by=owner, updated_by=owner)


def _auth_client(user):
    """Helper — logs the user in via simplejwt and returns an APIClient with the bearer header attached."""
    client = APIClient()
    from rest_framework_simplejwt.tokens import RefreshToken
    token = RefreshToken.for_user(user).access_token
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return client


@pytest.fixture
def buyer_client(buyer_user): return _auth_client(buyer_user)


@pytest.fixture
def supplier_client(supplier_user): return _auth_client(supplier_user)


@pytest.fixture
def verified_supplier_client(verified_supplier): return _auth_client(verified_supplier)


@pytest.fixture
def admin_client(admin_user): return _auth_client(admin_user)
