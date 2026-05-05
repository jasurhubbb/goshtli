"""Shared pytest fixtures — provides admin/supplier/buyer users + an authenticated APIClient per role.

Why fixtures here (project root) rather than per-app conftest: the same fixtures are reused across every app's
test module, so co-locating them here means less duplication. Tests pull what they need by argument name.
"""
import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.suppliers.models import SupplierProfile


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
