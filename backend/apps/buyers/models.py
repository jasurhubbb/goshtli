"""BuyerProfile — extra info for User with role=BUYER. No verification gate; buyers can order immediately after signup."""
from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


class BuyerProfile(TimeStampedModel):
    """One-to-one with User. Holds business info used at checkout/dashboard; ordering itself uses User.id directly."""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                related_name="buyer_profile", limit_choices_to={"role": "BUYER"})
    business_name = models.CharField(_("business name"), max_length=200, blank=True)
    region = models.CharField(_("region"), max_length=100, blank=True)
    address = models.TextField(_("address"), blank=True)

    class Meta:
        verbose_name = _("buyer profile")
        verbose_name_plural = _("buyer profiles")

    def __str__(self): return f"{self.business_name or self.user.email}"
