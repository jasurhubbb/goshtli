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

    v3.1 expansion: added structured delivery hints (entrance/floor/apartment/notes) + lat/lng for the
    map-picker UX. The `address` field stays as the freeform street line; the new fields are courier hints.
    is_default is enforced "at most one per user" at save() time — simpler than a partial unique index.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="saved_addresses", db_index=True)
    label = models.CharField(_("label"), max_length=50, help_text=_("e.g. Uy, Ofis, Restoran"))
    address = models.TextField(_("address"), help_text=_("Street line — e.g. 'Bobur mahalla fuqarolar yig'ini, 6'"))

    # ---- v3.1: structured courier hints. All optional — couriers use what's filled in. ----
    entrance = models.CharField(_("entrance"), max_length=20, blank=True, help_text=_("Kirish yo'lagi"))
    floor = models.CharField(_("floor"), max_length=20, blank=True, help_text=_("Qavat"))
    apartment = models.CharField(_("apartment"), max_length=20, blank=True, help_text=_("Xonadon"))
    notes = models.TextField(_("notes"), blank=True,
                             help_text=_("Belgilangan joy va manzil tafsilotlari — helps the courier find you faster"))

    # Lat/Lng captured from the map picker. Nullable so users who skip the map (or are on older clients) can still save.
    # Decimal precision 9.6 = sub-meter accuracy, more than GPS gives us.
    lat = models.DecimalField(_("latitude"), max_digits=9, decimal_places=6, null=True, blank=True)
    lng = models.DecimalField(_("longitude"), max_digits=9, decimal_places=6, null=True, blank=True)

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
