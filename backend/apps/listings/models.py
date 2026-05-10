"""Listing — meat stock entry. Buyers can order only from ACTIVE listings; quantity is mutated atomically by the orders service.

v2 additions (Milestone A):
  • Multiple photos per listing (see ListingPhoto below) — required ≥ 1 in the create endpoint
  • halal_certified flag → badge on listing cards
  • freshness_date (slaughter date) → buyer-visible freshness signal
  • cold_chain enum (Fresh / Chilled / Frozen) → state of the meat
  • service_area_csv → comma-separated region names this supplier delivers to; filter on search

Also: supplier FK no longer has limit_choices_to — the unified user model lets anyone become a supplier
(creation gate moved entirely to SupplierProfile.is_verified check in the view layer).
"""
from decimal import Decimal
from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


class Listing(TimeStampedModel):
    class MeatType(models.TextChoices):
        # Closed enum so filtering "by meat_type" is reliable; OTHER is the escape hatch for edge cases
        BEEF = "BEEF", _("Beef")
        MUTTON = "MUTTON", _("Mutton")
        CHICKEN = "CHICKEN", _("Chicken")
        GOAT = "GOAT", _("Goat")
        HORSE = "HORSE", _("Horse")
        OTHER = "OTHER", _("Other")

    class Status(models.TextChoices):
        # ACTIVE = visible to buyers; SOLD_OUT = stock hit zero; INACTIVE = supplier hid it manually
        ACTIVE = "ACTIVE", _("Active")
        SOLD_OUT = "SOLD_OUT", _("Sold out")
        INACTIVE = "INACTIVE", _("Inactive")

    class ColdChain(models.TextChoices):
        # State of the meat — drives buyer expectations on shelf-life + display badges
        FRESH = "FRESH", _("Fresh")              # Yangi — never frozen or chilled, slaughter same day
        CHILLED = "CHILLED", _("Chilled")        # Sovutilgan — kept at 0–4°C
        FROZEN = "FROZEN", _("Frozen")           # Muzlatilgan — below -18°C

    # Unified user model: any user can hold listings. Verification check (SupplierProfile.is_verified) lives in the view.
    supplier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                 related_name="listings", db_index=True)
    title = models.CharField(_("title"), max_length=200)
    meat_type = models.CharField(_("meat type"), max_length=10, choices=MeatType.choices, db_index=True)
    # Decimal (not Float) — money/weight need exact arithmetic; quantity_kg is mutated by orders service under select_for_update
    quantity_kg = models.DecimalField(_("quantity (kg)"), max_digits=10, decimal_places=2,
                                      validators=[MinValueValidator(Decimal("0.00"))])
    price_per_kg = models.DecimalField(_("price per kg"), max_digits=10, decimal_places=2,
                                       validators=[MinValueValidator(Decimal("0.01"))])
    location = models.CharField(_("location"), max_length=200, db_index=True)
    available_from = models.DateField(_("available from"))
    description = models.TextField(_("description"), blank=True)
    status = models.CharField(_("status"), max_length=10, choices=Status.choices, default=Status.ACTIVE, db_index=True)

    # v2 fields ----------------------------------------------------------------
    halal_certified = models.BooleanField(_("halal certified"), default=False, db_index=True)
    freshness_date = models.DateField(_("freshness date (slaughter date)"), null=True, blank=True)
    cold_chain = models.CharField(_("cold chain"), max_length=10, choices=ColdChain.choices,
                                  default=ColdChain.FRESH, db_index=True)
    # CSV of region names — simple v2 implementation; upgrade to M2M(Region) when admin needs to manage region list
    service_area_csv = models.CharField(_("service areas (comma-separated)"), max_length=500, blank=True,
                                        help_text=_("Comma-separated region names the supplier delivers to"))

    class Meta:
        verbose_name = _("listing")
        verbose_name_plural = _("listings")
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("status", "meat_type", "location"))]  # supports common filter combinations

    def __str__(self): return f"{self.title} ({self.quantity_kg}kg @ {self.price_per_kg}, {self.status})"


def _listing_photo_path(instance, filename):
    """Storage path: listings/<id>/<filename>. Keeps photos grouped per listing — easy to clean on delete."""
    return f"listings/{instance.listing_id}/{filename}"


class ListingPhoto(TimeStampedModel):
    """One image attached to a listing. Multiple per listing; the first one (lowest position) is the thumbnail."""
    listing = models.ForeignKey(Listing, on_delete=models.CASCADE, related_name="photos", db_index=True)
    image = models.ImageField(_("image"), upload_to=_listing_photo_path)
    position = models.PositiveSmallIntegerField(_("position"), default=0,
                                                help_text=_("Lower = shown first; 0 is the primary thumbnail"))

    class Meta:
        verbose_name = _("listing photo")
        verbose_name_plural = _("listing photos")
        ordering = ("position", "id")

    def __str__(self): return f"Photo {self.id} of listing {self.listing_id}"
