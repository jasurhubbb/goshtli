"""Custom user manager — required because we use email as the login identifier instead of Django's default username."""
from django.contrib.auth.base_user import BaseUserManager
from django.utils.translation import gettext_lazy as _


class UserManager(BaseUserManager):
    """Drives create_user / create_superuser. Email is normalized + required; password is hashed via set_password."""
    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        # Both email and password are mandatory — refusing here prevents silent half-created accounts
        if not email: raise ValueError(_("Email is required"))
        if not password: raise ValueError(_("Password is required"))
        email = self.normalize_email(email)  # lowercases the domain part for consistent lookups
        user = self.model(email=email, **extra_fields)
        user.set_password(password)  # hashes via PBKDF2 (Django default) — never stores raw password
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        # Standard end-user account — defaults to BUYER role per database-design spec; caller can override
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        extra_fields.setdefault("role", "BUYER")
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        # Django Admin superuser — forced to ADMIN role so role-based permissions match the admin flag
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        extra_fields.setdefault("role", "ADMIN")
        if extra_fields.get("is_staff") is not True: raise ValueError(_("Superuser must have is_staff=True"))
        if extra_fields.get("is_superuser") is not True: raise ValueError(_("Superuser must have is_superuser=True"))
        return self._create_user(email, password, **extra_fields)

    def create_user_from_phone(self, phone, full_name, **extra_fields):
        """Phone-only registration (v3.2 buyer flow). No password, no real email — Django still requires both
        for AbstractBaseUser, so we synthesize a non-clashing placeholder email and an unusable password.
        The user authenticates by phone via the dedicated PhoneLoginView; the synthetic email never reaches them.

        Phone uniqueness is enforced by the partial UniqueConstraint on User (see models.py); raises IntegrityError
        if phone already exists, which the view layer turns into a 409 / friendly error.
        """
        if not phone: raise ValueError(_("Phone is required"))
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        extra_fields.setdefault("role", "BUYER")
        # Synthetic email: strip the +, suffix .phone.goshtli.local — guaranteed unique because phone is unique
        synthetic_email = f"{phone.lstrip('+')}@phone.goshtli.local"
        user = self.model(email=synthetic_email, phone=phone, full_name=full_name, **extra_fields)
        user.set_unusable_password()  # password-less account; logins go through PhoneLoginView, not /auth/login/
        user.save(using=self._db)
        return user
