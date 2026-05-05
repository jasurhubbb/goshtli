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
