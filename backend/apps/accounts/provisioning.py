"""One place that mints admin-issued work-app accounts.

SUPPLIER is retained as the wire role for listing ownership. Accounts created here additionally receive
the explicit internal-catalog marker; legacy external SUPPLIER rows do not. QASSOB and COURIER remain
external operational roles. The admin endpoint and provision_* commands share this path.

The account logs in with the returned phone + password. Qassobs complete their profile wizard;
catalog operators and couriers enter their dedicated workspaces directly.
"""
import secrets

from .models import User


def generate_password() -> str:
    """8-char url-safe password, handed to the partner once. Not stored in plaintext anywhere (User stores the
    PBKDF2 hash); the caller is responsible for delivering it."""
    return secrets.token_urlsafe(6)[:8]


def _ensure_profile(user, role: str, *, full_name: str, business_name: str = ""):
    """Create the role's profile row if missing. Lazy imports avoid an import cycle."""
    if role == User.Role.SUPPLIER:
        from apps.suppliers.models import SupplierProfile
        SupplierProfile.objects.update_or_create(
            user=user, defaults={"business_name": business_name or "Platform Catalog",
                                 "full_name": full_name, "is_verified": True})
    elif role == User.Role.QASSOB:
        from apps.qassobs.models import QassobProfile
        # years_experience is NOT NULL with no default — must be supplied or the create raises IntegrityError.
        QassobProfile.objects.get_or_create(
            user=user, defaults={"full_name": full_name, "years_experience": 0, "region": "", "address": ""})
    elif role == User.Role.COURIER:
        from apps.couriers.models import CourierProfile
        CourierProfile.objects.get_or_create(user=user, defaults={"full_name": full_name})


def provision_partner_account(*, phone: str, full_name: str, role: str, password: str = "",
                              business_name: str = ""):
    """Create-or-update a partner User (usable password) + its minimal profile. Idempotent on phone.
    Returns (user, password, created) — password is the plaintext to hand over (generated if not supplied)."""
    if role not in (User.Role.SUPPLIER, User.Role.QASSOB, User.Role.COURIER):
        raise ValueError(f"role must be SUPPLIER/QASSOB/COURIER, got {role!r}")
    password = password or generate_password()
    user, created = User.objects.provision_partner(
        phone=phone, full_name=full_name, role=role, password=password)
    _ensure_profile(user, role, full_name=full_name, business_name=business_name)
    return user, password, created
