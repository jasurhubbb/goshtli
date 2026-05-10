"""SupplierProfile — opt-in capability attached to any User in v2.

In v1 this was auto-created on register when role=SUPPLIER. v2 unified user: anyone can opt into selling — they
POST /api/v1/suppliers/me/ to create the profile, then admin flips is_verified=True before they can list.

v2 additions:
  • photo — profile / business photo (logo or shopfront)
  • description — about the business
  • phone_visible — controls whether buyers see supplier's phone in the listing detail
"""
from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


def _supplier_photo_path(instance, filename):
    return f"suppliers/{instance.user_id}/{filename}"


class SupplierProfile(TimeStampedModel):
    """One-to-one with User — opt-in. is_verified gates listing creation; only admin can flip it."""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                related_name="supplier_profile")
    business_name = models.CharField(_("business name"), max_length=200)
    region = models.CharField(_("region"), max_length=100, blank=True)
    address = models.TextField(_("address"), blank=True)
    description = models.TextField(_("about the business"), blank=True)
    photo = models.ImageField(_("photo"), upload_to=_supplier_photo_path, blank=True, null=True)
    phone_visible = models.BooleanField(_("show phone to buyers"), default=True,
                                        help_text=_("If true, supplier's phone is shown on listing detail"))
    # is_verified defaults to False — admin gates listing creation
    is_verified = models.BooleanField(_("is verified"), default=False, db_index=True)

    class Meta:
        verbose_name = _("supplier profile")
        verbose_name_plural = _("supplier profiles")

    def __str__(self): return f"{self.business_name or self.user.email} (verified={self.is_verified})"
