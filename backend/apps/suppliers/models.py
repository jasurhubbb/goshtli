"""SupplierProfile — extra info attached to a User with role=SUPPLIER. Verification gate for listing creation lives here."""
from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


class SupplierProfile(TimeStampedModel):
    """One-to-one with User. is_verified gates listing creation per business rules; only admin can flip it."""
    # OneToOne ensures a user has at most one supplier profile; CASCADE so deleting the user cleans the profile
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                related_name="supplier_profile", limit_choices_to={"role": "SUPPLIER"})
    business_name = models.CharField(_("business name"), max_length=200)
    region = models.CharField(_("region"), max_length=100, blank=True)
    address = models.TextField(_("address"), blank=True)
    # is_verified defaults to False — supplier cannot create listings until admin sets this to True
    is_verified = models.BooleanField(_("is verified"), default=False, db_index=True)

    class Meta:
        verbose_name = _("supplier profile")
        verbose_name_plural = _("supplier profiles")

    def __str__(self): return f"{self.business_name or self.user.email} (verified={self.is_verified})"
