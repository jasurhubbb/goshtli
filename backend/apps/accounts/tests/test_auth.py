"""Auth endpoint tests — register, login, refresh, /me. Covers both happy and sad paths to lock the public auth contract."""
import pytest


@pytest.mark.django_db
class TestRegister:
    """Public registration — buyers/suppliers only, password validation, no admin-self-registration."""

    def test_register_buyer_returns_201_and_user_data(self, api):
        r = api.post("/api/v1/auth/register/", {"email": "new@buy.local", "full_name": "New Buyer",
                                                 "password": "StrongPass123!", "phone": "", "role": "BUYER"}, format="json")
        assert r.status_code == 201
        # Password must never be echoed back in any response
        assert "password" not in r.data and r.data["email"] == "new@buy.local" and r.data["role"] == "BUYER"

    def test_register_supplier_creates_supplier_profile_via_signal(self, api):
        r = api.post("/api/v1/auth/register/", {"email": "new@supp.local", "full_name": "New Supplier",
                                                 "password": "StrongPass123!", "role": "SUPPLIER"}, format="json")
        assert r.status_code == 201
        # Signal should auto-create SupplierProfile so /suppliers/me/ never 404s after registration
        from apps.suppliers.models import SupplierProfile
        assert SupplierProfile.objects.filter(user__email="new@supp.local").exists()

    def test_register_with_admin_role_is_rejected(self, api):
        r = api.post("/api/v1/auth/register/", {"email": "x@x.local", "full_name": "X",
                                                 "password": "StrongPass123!", "role": "ADMIN"}, format="json")
        assert r.status_code == 400 and "role" in r.data

    def test_register_with_weak_password_is_rejected_with_field_errors(self, api):
        r = api.post("/api/v1/auth/register/", {"email": "x@x.local", "full_name": "X",
                                                 "password": "123", "role": "BUYER"}, format="json")
        assert r.status_code == 400 and "password" in r.data

    def test_register_with_duplicate_email_is_rejected(self, api, buyer_user):
        r = api.post("/api/v1/auth/register/", {"email": buyer_user.email, "full_name": "X",
                                                 "password": "StrongPass123!", "role": "BUYER"}, format="json")
        assert r.status_code == 400 and "email" in r.data


@pytest.mark.django_db
class TestLoginRefresh:
    """JWT login + refresh — must return access+refresh and rotate refresh on subsequent calls."""

    def test_login_returns_jwt_pair(self, api, buyer_user):
        r = api.post("/api/v1/auth/login/", {"email": buyer_user.email, "password": "StrongPass123!"}, format="json")
        assert r.status_code == 200 and "access" in r.data and "refresh" in r.data

    def test_login_with_wrong_password_returns_401(self, api, buyer_user):
        r = api.post("/api/v1/auth/login/", {"email": buyer_user.email, "password": "WrongPass!"}, format="json")
        assert r.status_code == 401

    def test_refresh_rotates_token(self, api, buyer_user):
        login = api.post("/api/v1/auth/login/", {"email": buyer_user.email, "password": "StrongPass123!"}, format="json")
        r = api.post("/api/v1/auth/refresh/", {"refresh": login.data["refresh"]}, format="json")
        # ROTATE_REFRESH_TOKENS=True returns a new refresh too
        assert r.status_code == 200 and "access" in r.data and "refresh" in r.data


@pytest.mark.django_db
class TestMe:
    """/auth/me/ — the canonical "who am I" endpoint; PATCH should permit name/phone but not role/email."""

    def test_me_requires_auth(self, api):
        assert api.get("/api/v1/auth/me/").status_code == 401

    def test_me_returns_current_user(self, buyer_client, buyer_user):
        r = buyer_client.get("/api/v1/auth/me/")
        assert r.status_code == 200 and r.data["email"] == buyer_user.email and r.data["role"] == "BUYER"

    def test_me_patch_updates_phone_but_not_role(self, buyer_client, buyer_user):
        r = buyer_client.patch("/api/v1/auth/me/", {"phone": "+998900000000", "role": "ADMIN"}, format="json")
        # role is read-only — value should still be BUYER even though we sent ADMIN
        assert r.status_code == 200 and r.data["phone"] == "+998900000000" and r.data["role"] == "BUYER"
