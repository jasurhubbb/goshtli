"""Custom User model — email-as-login, role enum (ADMIN/SUPPLIER/BUYER/QASSOB), inherits PermissionsMixin for groups + perms."""
from django.conf import settings
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel
from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin, TimeStampedModel):
    """Single user table for consumer, internal-catalog, and operational work roles."""

    class Role(models.TextChoices):
        # SUPPLIER is retained as the database/wire value for the private platform catalog workspace;
        # is_internal_catalog_operator is the actual access grant. QASSOB and COURIER remain work roles.
        ADMIN = "ADMIN", _("Admin")
        SUPPLIER = "SUPPLIER", _("Catalog operator")
        BUYER = "BUYER", _("Buyer")
        QASSOB = "QASSOB", _("Qassob")
        COURIER = "COURIER", _("Courier")

    # ---- Gender enum (v3.3 profile settings) ----
    class Gender(models.TextChoices):
        MALE = "M", _("Male")
        FEMALE = "F", _("Female")

    # Identity fields — email is the login key (unique + indexed); phone is required for B2B contact
    email = models.EmailField(_("email address"), unique=True)
    full_name = models.CharField(_("full name"), max_length=150)
    phone = models.CharField(_("phone"), max_length=20, blank=True)
    role = models.CharField(_("role"), max_length=10, choices=Role.choices, default=Role.BUYER)
    is_internal_catalog_operator = models.BooleanField(
        _("internal catalog operator"),
        default=False,
        help_text=_("Grants the legacy SUPPLIER account access to the platform's private catalog workspace."),
    )

    # ---- v3.3 profile settings — Familiya / Ism / Otasining ismi / Tug'ilgan kun / Jins ----
    # All optional so legacy + phone-registered accounts (which only have full_name) keep working untouched.
    # full_name remains the canonical display string; the settings screen recomputes it on save as "{last} {first}".
    first_name = models.CharField(_("first name"), max_length=80, blank=True)
    last_name = models.CharField(_("last name"), max_length=80, blank=True)
    patronymic = models.CharField(_("patronymic"), max_length=80, blank=True)
    date_of_birth = models.DateField(_("date of birth"), null=True, blank=True)
    gender = models.CharField(_("gender"), max_length=1, choices=Gender.choices, blank=True)

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
        # Partial unique constraint: phone is unique only when set. Allows many users with phone='' (the
        # CharField default), while still enforcing one-account-per-phone for the v3.2 phone-based auth flow.
        constraints = [
            models.UniqueConstraint(
                fields=("phone",), name="user_phone_unique_when_present",
                condition=models.Q(phone__gt="")),
        ]

    def __str__(self): return f"{self.email} ({self.role})"

    # Convenience role checks used by permissions classes — keeps `if user.is_supplier` readable in views
    @property
    def is_admin_role(self): return self.role == self.Role.ADMIN
    @property
    def is_catalog_operator(self):
        """Platform catalog staff; legacy external SUPPLIER rows do not pass this gate."""
        return self.role == self.Role.SUPPLIER and self.is_internal_catalog_operator
    @property
    def is_supplier(self): return self.is_catalog_operator
    @property
    def is_buyer(self): return self.role == self.Role.BUYER
    @property
    def is_qassob(self): return self.role == self.Role.QASSOB
    @property
    def is_courier(self): return self.role == self.Role.COURIER
    @property
    def is_partner(self):
        """Any work-app role; SUPPLIER accounts qualify only when explicitly marked as internal staff."""
        return self.is_catalog_operator or self.role in (self.Role.QASSOB, self.Role.COURIER)


def kyc_upload_path(instance, filename):
    """Store KYC docs scoped by user id so admin cleanup is one-folder-delete. Lives under /media/kyc/<user>/."""
    return f"kyc/{instance.user_id}/{filename}"


class KYCDocument(TimeStampedModel):
    """Identity verification artefacts uploaded by partners (Suppliers + Qassobs) during onboarding.

    Workflow: partner uploads PASSPORT + BUSINESS_LICENSE (+ optional facility photo) → admin reviews
    each row in Django Admin → flips `is_approved` per row. A post-save signal checks whether the
    REQUIRED set is fully approved and, if so, flips the partner's profile.is_verified to True and
    enqueues an FCM push ("Tabriklaymiz! Endi to'liq foydalanishingiz mumkin").

    PCI/privacy: images are stored in R2 (private bucket) when configured; admin-only access path.
    No OCR or extraction — humans review in admin.
    """

    class Kind(models.TextChoices):
        PASSPORT = "PASSPORT", _("Passport / ID")
        BUSINESS_LICENSE = "BUSINESS_LICENSE", _("Business license")
        FACILITY_PHOTO = "FACILITY_PHOTO", _("Facility / workplace photo")
        OTHER = "OTHER", _("Other")

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="kyc_docs", db_index=True)
    kind = models.CharField(_("document type"), max_length=24, choices=Kind.choices)
    image = models.ImageField(_("scan / photo"), upload_to=kyc_upload_path)
    admin_notes = models.TextField(_("admin notes"), blank=True,
                                   help_text=_("Private — visible only to admins. Reason for approval/rejection."))
    is_approved = models.BooleanField(_("approved"), default=False, db_index=True)

    class Meta:
        verbose_name = _("KYC document")
        verbose_name_plural = _("KYC documents")
        ordering = ("-created_at",)
        constraints = [
            # Each user can have at most one document of each kind (PASSPORT, BUSINESS_LICENSE, etc.). A
            # new upload of the same kind should REPLACE the old one — the view layer enforces this via
            # update_or_create so admins never see duplicate-pending rows.
            models.UniqueConstraint(fields=("user", "kind"), name="uniq_kyc_doc_per_kind"),
        ]

    def __str__(self): return f"KYC {self.kind} for {self.user.email} ({'approved' if self.is_approved else 'pending'})"
