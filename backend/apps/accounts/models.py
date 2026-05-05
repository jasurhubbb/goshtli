"""Custom User model — email-as-login, role enum (ADMIN/SUPPLIER/BUYER), inherits PermissionsMixin for groups + perms."""
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel
from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin, TimeStampedModel):
    """Single user table for all roles — role field decides which profile (Supplier/Buyer) and permissions apply."""

    class Role(models.TextChoices):
        # Three fixed roles per database-design spec; every user has exactly one
        ADMIN = "ADMIN", _("Admin")
        SUPPLIER = "SUPPLIER", _("Supplier")
        BUYER = "BUYER", _("Buyer")

    # Identity fields — email is the login key (unique + indexed); phone is required for B2B contact
    email = models.EmailField(_("email address"), unique=True)
    full_name = models.CharField(_("full name"), max_length=150)
    phone = models.CharField(_("phone"), max_length=20, blank=True)
    role = models.CharField(_("role"), max_length=10, choices=Role.choices, default=Role.BUYER)

    # Django auth flags — is_active gates login; is_staff gates Django Admin access (only admins set this)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    objects = UserManager()
    USERNAME_FIELD = "email"        # auth backend uses this field as the login identifier
    REQUIRED_FIELDS = ["full_name"]  # prompted by createsuperuser in addition to email + password

    class Meta:
        verbose_name = _("user")
        verbose_name_plural = _("users")
        ordering = ("-created_at",)

    def __str__(self): return f"{self.email} ({self.role})"

    # Convenience role checks used by permissions classes — keeps `if user.is_supplier` readable in views
    @property
    def is_admin_role(self): return self.role == self.Role.ADMIN
    @property
    def is_supplier(self): return self.role == self.Role.SUPPLIER
    @property
    def is_buyer(self): return self.role == self.Role.BUYER
