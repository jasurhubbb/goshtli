"""BuyerProfile + SavedAddress — profile auto-created for every user; addresses are explicit user choices saved
for one-tap reuse at checkout (the second model is new in v2 Milestone E)."""
from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


class BuyerProfile(TimeStampedModel):
    """One-to-one with User — auto-created via signal for every account."""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="buyer_profile")
    business_name = models.CharField(_("business name"), max_length=200, blank=True)
    region = models.CharField(_("region"), max_length=100, blank=True)
    address = models.TextField(_("address"), blank=True)

    class Meta:
        verbose_name = _("buyer profile")
        verbose_name_plural = _("buyer profiles")

    def __str__(self): return f"{self.business_name or self.user.email}"


class SavedAddress(TimeStampedModel):
    """One named delivery address per row. Users can save many; pick one at checkout instead of typing.

    is_default is enforced "at most one per user" at save() time — simpler than a partial unique index, fine for v2.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="saved_addresses", db_index=True)
    label = models.CharField(_("label"), max_length=50, help_text=_("e.g. Uy, Ofis, Restoran"))
    address = models.TextField(_("address"))
    is_default = models.BooleanField(_("default"), default=False)

    class Meta:
        verbose_name = _("saved address")
        verbose_name_plural = _("saved addresses")
        ordering = ("-is_default", "-created_at")
        indexes = [models.Index(fields=("user", "-is_default"))]

    def save(self, *args, **kwargs):
        # Enforce at-most-one default per user — if this row is being set default, clear siblings first
        if self.is_default:
            SavedAddress.objects.filter(user=self.user, is_default=True).exclude(pk=self.pk).update(is_default=False)
        super().save(*args, **kwargs)

    def __str__(self): return f"{self.label} — {self.user.email}"
