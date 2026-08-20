"""Auth endpoint tests — register, login, refresh, /me. Covers both happy and sad paths to lock the public auth contract."""
from io import StringIO

import pytest
from django.core.management import call_command


@pytest.mark.django_db
class TestRegister:
    """Public registration is buyer-only; internal and partner roles are provisioned by admins."""

    def test_register_buyer_returns_201_and_user_data(self, api):
        r = api.post("/api/v1/auth/register/", {"email": "new@buy.local", "full_name": "New Buyer",
                                                 "password": "StrongPass123!", "phone": "", "role": "BUYER"}, format="json")
        assert r.status_code == 201
        # Password must never be echoed back in any response
        assert "password" not in r.data and r.data["email"] == "new@buy.local" and r.data["role"] == "BUYER"

    def test_register_supplier_is_rejected(self, api):
        r = api.post("/api/v1/auth/register/", {"email": "new@supp.local", "full_name": "New Supplier",
                                                 "password": "StrongPass123!", "role": "SUPPLIER"}, format="json")
        assert r.status_code == 400 and "role" in r.data

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

    @pytest.mark.parametrize("role", ("ADMIN", "SUPPLIER", "QASSOB", "COURIER"))
    def test_email_login_rejects_every_non_buyer_role(self, api, role):
        from apps.accounts.models import User

        user = User.objects.create_user(
            email=f"{role.lower()}-email-login@test.local",
            password="StrongPass123!",
            full_name=role,
            role=role,
            is_internal_catalog_operator=role == User.Role.SUPPLIER,
        )
        r = api.post("/api/v1/auth/login/", {
            "email": user.email, "password": "StrongPass123!",
        }, format="json")
        assert r.status_code == 401
        assert "access" not in r.data and "refresh" not in r.data

    def test_refresh_rotates_token(self, api, buyer_user):
        login = api.post("/api/v1/auth/login/", {"email": buyer_user.email, "password": "StrongPass123!"}, format="json")
        r = api.post("/api/v1/auth/refresh/", {"refresh": login.data["refresh"]}, format="json")
        # ROTATE_REFRESH_TOKENS=True returns a new refresh too
        assert r.status_code == 200 and "access" in r.data and "refresh" in r.data


@pytest.mark.django_db
class TestAppRoleBoundaries:
    """Buyer and partner login surfaces must not mint sessions for the other app."""

    def test_phone_register_without_role_creates_buyer(self, api):
        from apps.accounts.models import User
        r = api.post("/api/v1/auth/phone-register/", {
            "phone": "+998901234559", "full_name": "Phone buyer",
        }, format="json")
        assert r.status_code == 201
        assert User.objects.get(phone="+998901234559").role == User.Role.BUYER

    def test_phone_register_rejects_internal_catalog_role(self, api):
        r = api.post("/api/v1/auth/phone-register/", {
            "phone": "+998901234560", "full_name": "Catalog operator", "role": "SUPPLIER",
        }, format="json")
        assert r.status_code == 400 and "role" in r.data

    def test_buyer_phone_login_rejects_internal_catalog_account(self, api):
        from apps.accounts.models import User
        User.objects.create_user(
            email="catalog@test.local", password="StrongPass123!", full_name="Catalog operator",
            phone="+998901234561", role=User.Role.SUPPLIER,
            is_internal_catalog_operator=True)
        r = api.post("/api/v1/auth/phone-login/", {"phone": "+998901234561"}, format="json")
        assert r.status_code == 403
        assert "access" not in r.data and "refresh" not in r.data

    def test_partner_login_rejects_buyer_account(self, api):
        from apps.accounts.models import User
        User.objects.create_user(
            email="phone-buyer@test.local", password="StrongPass123!", full_name="Buyer",
            phone="+998901234562", role=User.Role.BUYER)
        r = api.post("/api/v1/auth/phone-password-login/", {
            "phone": "+998901234562", "password": "StrongPass123!",
        }, format="json")
        assert r.status_code == 401
        assert "access" not in r.data and "refresh" not in r.data

    def test_partner_login_accepts_internal_catalog_account(self, api):
        from apps.accounts.models import User
        User.objects.create_user(
            email="catalog-login@test.local", password="StrongPass123!", full_name="Catalog operator",
            phone="+998901234563", role=User.Role.SUPPLIER,
            is_internal_catalog_operator=True)
        r = api.post("/api/v1/auth/phone-password-login/", {
            "phone": "+998901234563", "password": "StrongPass123!",
        }, format="json")
        assert r.status_code == 200
        assert "access" in r.data and "refresh" in r.data

    def test_partner_login_rejects_legacy_supplier_without_internal_flag(self, api):
        from apps.accounts.models import User

        user = User.objects.create_user(
            email="legacy-supplier-login@test.local",
            password="StrongPass123!",
            full_name="Legacy supplier",
            phone="+998901234565",
            role=User.Role.SUPPLIER,
        )
        assert not user.is_catalog_operator
        assert not user.is_partner

        r = api.post("/api/v1/auth/phone-password-login/", {
            "phone": user.phone, "password": "StrongPass123!",
        }, format="json")
        assert r.status_code == 401
        assert "access" not in r.data and "refresh" not in r.data

    def test_legacy_supplier_session_cannot_bootstrap_from_me(self, api):
        from rest_framework_simplejwt.tokens import RefreshToken
        from apps.accounts.models import User

        user = User.objects.create_user(
            email="legacy-session@test.local",
            password="StrongPass123!",
            full_name="Legacy supplier",
            role=User.Role.SUPPLIER,
        )
        access = RefreshToken.for_user(user).access_token
        api.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

        assert api.get("/api/v1/auth/me/").status_code == 403

    def test_buyer_cannot_enter_catalog_endpoints(self, buyer_client):
        assert buyer_client.get("/api/v1/suppliers/me/").status_code == 403
        assert buyer_client.get("/api/v1/markets/me/").status_code == 403
        assert buyer_client.get("/api/v1/orders/supplier/").status_code == 403

    def test_catalog_operator_cannot_enter_buyer_order_endpoint(self, supplier_client):
        assert supplier_client.get("/api/v1/orders/my/").status_code == 403


@pytest.mark.django_db
class TestCatalogOperatorProvisioning:
    def test_command_creates_verified_internal_catalog_account(self):
        from apps.accounts.models import User
        from apps.suppliers.models import SupplierProfile

        stdout = StringIO()
        call_command(
            "provision_catalog_operator",
            phone="+998901234564",
            name="Catalog Team",
            password="StrongPass123!",
            stdout=stdout,
        )

        user = User.objects.get(phone="+998901234564")
        profile = SupplierProfile.objects.get(user=user)
        assert user.role == User.Role.SUPPLIER
        assert user.is_internal_catalog_operator
        assert user.is_catalog_operator
        assert user.check_password("StrongPass123!")
        assert profile.business_name == "Platform Catalog"
        assert profile.is_verified
        assert "Created catalog operator" in stdout.getvalue()

    def test_admin_provisioning_sets_and_revokes_internal_catalog_flag(self, admin_client):
        from apps.accounts.models import User

        phone = "+998901234566"
        created = admin_client.post("/api/v1/auth/admin/provision-partner/", {
            "phone": phone,
            "full_name": "Catalog Team",
            "password": "StrongPass123!",
            "role": User.Role.SUPPLIER,
        }, format="json")
        assert created.status_code == 201
        user = User.objects.get(phone=phone)
        assert user.is_internal_catalog_operator
        assert user.is_catalog_operator

        reprovisioned = admin_client.post("/api/v1/auth/admin/provision-partner/", {
            "phone": phone,
            "full_name": "Operations Team",
            "password": "NewStrongPass123!",
            "role": User.Role.QASSOB,
        }, format="json")
        assert reprovisioned.status_code == 201
        user.refresh_from_db()
        assert not user.is_internal_catalog_operator
        assert not user.is_catalog_operator
        assert user.is_partner


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
