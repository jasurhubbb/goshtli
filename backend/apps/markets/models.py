"""Market — the vendor entity. Every Listing belongs to exactly one Market; buyers browse "products by market"
or "products by category across all markets", matching the Wolt/Uber Eats marketplace UX.

A Market carries everything the buyer needs to evaluate "should I order from this place?": brand identity
(logo + cover photo), location (address + lat/lng for distance-from-me sort), and operating hours.
Markets cannot be hard-deleted — set is_active=False to hide from buyers while preserving order history.
"""
from django.conf import settings
from django.db import models
from django.utils.text import slugify
from django.utils.translation import gettext_lazy as _
from simple_history.models import HistoricalRecords

from apps.common.models import TimeStampedModel


def _market_logo_path(instance, filename):
    """Storage path: markets/<slug>/logo/<filename>. Slug-based so admin rename doesn't orphan the file."""
    return f"markets/{instance.slug or 'unset'}/logo/{filename}"


def _market_cover_path(instance, filename):
    """Storage path: markets/<slug>/cover/<filename>. Same grouping convention as the logo."""
    return f"markets/{instance.slug or 'unset'}/cover/{filename}"


class Market(TimeStampedModel):
    """One vendor on the platform. Holds branding, location, and operating-hours metadata; the
    products themselves live in apps.listings.Listing with a FK back here."""

    # ---- Identity ---------------------------------------------------------------
    # Slug is the public URL key — buyers see /markets/osh-bozor, not /markets/47. Auto-derived from name_uz
    # on save if blank, but admins can override (useful for transliteration / SEO).
    slug = models.SlugField(_("slug"), max_length=120, unique=True, db_index=True,
                            help_text=_("URL-safe key; auto-generated from Uzbek name if left blank"))
    # Bilingual names — kept as separate columns rather than a JSONField so we can index/sort/filter cleanly per locale
    name_uz = models.CharField(_("name (Uzbek)"), max_length=200)
    name_ru = models.CharField(_("name (Russian)"), max_length=200)
    description_uz = models.TextField(_("description (Uzbek)"), blank=True)
    description_ru = models.TextField(_("description (Russian)"), blank=True)

    # ---- Location ---------------------------------------------------------------
    # Region drives the buyer's "near me" filter — kept as a CharField for now; promote to FK(Region) when the
    # admin needs to manage the region list from the dashboard rather than from code.
    address = models.CharField(_("address"), max_length=300)
    region = models.CharField(_("region"), max_length=80, db_index=True,
                              help_text=_("e.g. Toshkent, Samarqand — drives 'near me' filtering"))
    # Lat/Lng for distance sort. Nullable because workers may onboard a market before pinning the exact location.
    # Decimal precision: 9.6 lets us store sub-meter precision (well past what GPS gives us).
    lat = models.DecimalField(_("latitude"), max_digits=9, decimal_places=6, null=True, blank=True)
    lng = models.DecimalField(_("longitude"), max_digits=9, decimal_places=6, null=True, blank=True)

    # ---- Contact + brand --------------------------------------------------------
    phone = models.CharField(_("phone"), max_length=20, blank=True,
                             help_text=_("Used by support when buyers can't reach the market"))
    # JSONField for opening hours — keeps the schema flexible across the many "open Mon-Fri" / "24/7" / "closed Sun"
    # variations. Frontend renders from a known shape, e.g. {"mon": [9, 21], "sun": null}.
    working_hours = models.JSONField(_("working hours"), default=dict, blank=True,
                                     help_text=_("Per-day hours as {weekday: [open_hour, close_hour]} or null=closed"))
    logo = models.ImageField(_("logo"), upload_to=_market_logo_path, null=True, blank=True,
                             help_text=_("Square brand mark; shown on market cards + chat avatars"))
    cover = models.ImageField(_("cover photo"), upload_to=_market_cover_path, null=True, blank=True,
                              help_text=_("Wide hero image on the market detail screen"))

    # ---- Lifecycle --------------------------------------------------------------
    # Soft-deletion flag — buyers only see is_active=True markets, but rows stick around so orders/audit trails
    # don't lose their FK targets. Setting is_active=False is the "archive" action for markets.
    is_active = models.BooleanField(_("active"), default=True, db_index=True,
                                    help_text=_("Uncheck to hide from buyers; row stays in DB for history"))

    # v3.3: each Market gets a backing SUPPLIER user that owns its listings. Auto-created in
    # MarketSerializer.create() so the in-app admin can pick a Market when creating a listing and the
    # backend resolves market.owner_user → Listing.supplier transparently. Nullable so historical rows
    # + the migration don't break; new rows get one immediately.
    owner_user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                      null=True, blank=True, related_name="owned_market",
                                      help_text=_("Backing SUPPLIER user — auto-created with the market; owns its listings"))

    # ---- Audit fields (manual; django-simple-history adds the row-level log separately) ----
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="markets_created", editable=False)
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="markets_updated", editable=False)

    # django-simple-history — automatic row-level audit trail. Every save() creates a row in markets_historicalmarket
    # tagged with the user from HistoryRequestMiddleware. updated_at is excluded so the diff focuses on real changes.
    history = HistoricalRecords(excluded_fields=["updated_at"])

    class Meta:
        verbose_name = _("market")
        verbose_name_plural = _("markets")
        ordering = ("name_uz",)
        # Region + active is the buyer's primary filter; indexed combo cuts the query plan for "markets near me"
        indexes = [models.Index(fields=("region", "is_active"), name="market_region_active_idx")]

    def __str__(self): return f"{self.name_uz} ({self.region})"

    def save(self, *args, **kwargs):
        """Auto-fill the slug from name_uz on first save. Admins can override before saving."""
        if not self.slug:
            self.slug = slugify(self.name_uz)[:120] or "market"
        super().save(*args, **kwargs)
