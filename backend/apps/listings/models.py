"""Listing — meat stock entry tied to a Market and a MeatCategory.

v3.1 catalog overhaul (this revision):
  • Listing now belongs to exactly one Market (multi-tenant marketplace pattern, like Wolt/Uber Eats)
  • meat_type CharField replaced by an FK to MeatCategory — admins manage categories from the dashboard
  • Bilingual content: name_uz/name_ru + description_uz/description_ru (no English; ARB layer never touches DB content)
  • Status enum simplified to ACTIVE / OUT_OF_STOCK / ARCHIVED. ARCHIVED rows persist for FK integrity but are
    invisible to buyers — there is no DRAFT or PAUSED state.
  • Dropped fields (deemed unnecessary for the buyer-only v3 app):
      halal_certified, freshness_date, cold_chain, service_area_csv

What's still here from v2:
  • supplier FK → User (the row's owner; usually = market.created_by but kept independent for flexibility)
  • Multiple photos via ListingPhoto, ordered by position
"""
from decimal import Decimal
from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils.text import slugify
from django.utils.translation import gettext_lazy as _
from simple_history.models import HistoricalRecords

from apps.common.models import TimeStampedModel


class MeatCategory(TimeStampedModel):
    """Top-level catalog facet — what kind of meat. Workers manage the list from Django Admin, so launching new
    categories doesn't require a code deploy. Default seed = 8 entries via data migration (mol, qo'y, tovuq, ...).

    Categories are referenced by Listing.category. They cannot be hard-deleted — set is_active=False to retire one
    without orphaning the listings that point at it.
    """

    # Slug is the public URL key (e.g. /catalog/mol-goshti). Auto-generated from name_uz on save if blank.
    slug = models.SlugField(_("slug"), max_length=80, unique=True, db_index=True,
                            help_text=_("URL-safe key; auto-generated from Uzbek name if left blank"))
    name_uz = models.CharField(_("name (Uzbek)"), max_length=100)
    name_ru = models.CharField(_("name (Russian)"), max_length=100)
    # Image is the production-quality category visual (uploaded photo/illustration, served from R2/CDN).
    # ImageField is nullable so admins can create a category and add the image asynchronously.
    image = models.ImageField(_("image"), upload_to="categories/%Y/", null=True, blank=True,
                              help_text=_("Square illustration / photo for buyer-side category cards"))
    # Lower display_order = shown first on the home grid. Gaps are fine (10, 20, 30 lets you insert in between later).
    display_order = models.PositiveSmallIntegerField(_("display order"), default=100, db_index=True,
                                                     help_text=_("Lower = shown first in the buyer category grid"))
    is_active = models.BooleanField(_("active"), default=True, db_index=True,
                                    help_text=_("Uncheck to retire a category without deleting its row"))

    class Meta:
        verbose_name = _("meat category")
        verbose_name_plural = _("meat categories")
        ordering = ("display_order", "name_uz")

    def __str__(self): return f"{self.name_uz}"

    def save(self, *args, **kwargs):
        """Auto-populate slug from name_uz on first save when admin leaves it blank."""
        if not self.slug:
            self.slug = slugify(self.name_uz)[:80] or "category"
        super().save(*args, **kwargs)


class Listing(TimeStampedModel):
    """One product on the catalog. Belongs to a Market (the vendor) and a MeatCategory (the facet).

    The class is still named `Listing` to minimize cross-app FK churn (orders, favorites, notifications all reference
    it). Admin UI presents it as "Product" via verbose_name. Renaming to Product is a follow-up refactor."""

    class Status(models.TextChoices):
        # ACTIVE     = visible to buyers + orderable
        # OUT_OF_STOCK = visible but greyed out; supplier needs to restock
        # ARCHIVED   = invisible to buyers, retained for FK integrity from orders/reviews/etc.
        ACTIVE = "ACTIVE", _("Active")
        OUT_OF_STOCK = "OUT_OF_STOCK", _("Out of stock")
        ARCHIVED = "ARCHIVED", _("Archived")

    # ---- Ownership + classification --------------------------------------------------------------
    # market: PROTECT delete so a market can't be hard-deleted while it still has listings (Admin uses soft-archive).
    market = models.ForeignKey("markets.Market", on_delete=models.PROTECT,
                               related_name="listings", db_index=True,
                               help_text=_("The vendor that owns this listing"))
    # category: PROTECT delete so admins can't accidentally retire a category that still has listings under it.
    category = models.ForeignKey("listings.MeatCategory", on_delete=models.PROTECT,
                                 related_name="listings", db_index=True,
                                 help_text=_("Top-level facet — buyers filter by this"))
    # supplier: the row's owner (separate from market.created_by — a supplier user account may operate one market,
    # but we keep the FK so legacy reads + multi-supplier-per-market scenarios still work).
    supplier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                 related_name="listings", db_index=True)

    # ---- Identity + bilingual content ------------------------------------------------------------
    # Slug is unique within a market (not globally) — two markets can both sell "premium-mol-goshti".
    slug = models.SlugField(_("slug"), max_length=140, db_index=True, blank=True,
                            help_text=_("URL-safe key; auto-generated from name_uz if left blank"))
    name_uz = models.CharField(_("name (Uzbek)"), max_length=200)
    name_ru = models.CharField(_("name (Russian)"), max_length=200, blank=True,
                               help_text=_("Russian translation; falls back to Uzbek if empty"))
    description_uz = models.TextField(_("description (Uzbek)"), blank=True)
    description_ru = models.TextField(_("description (Russian)"), blank=True)

    # ---- Commerce fields -------------------------------------------------------------------------
    # Decimal (not Float) — money/weight need exact arithmetic; quantity_kg is mutated under select_for_update by orders.
    quantity_kg = models.DecimalField(_("quantity (kg)"), max_digits=10, decimal_places=2,
                                      validators=[MinValueValidator(Decimal("0.00"))])
    price_per_kg = models.DecimalField(_("price per kg"), max_digits=10, decimal_places=2,
                                       validators=[MinValueValidator(Decimal("0.01"))])
    location = models.CharField(_("location"), max_length=200, blank=True, db_index=True,
                                help_text=_("Per-listing location override; usually inherits from market.address"))
    available_from = models.DateField(_("available from"))
    status = models.CharField(_("status"), max_length=15, choices=Status.choices, default=Status.ACTIVE, db_index=True)

    # ---- v3.6 Live animal (Tirik chorva) fields per PRD v2 ----------------------------------------
    # Per PRD §2: a listing can be raw meat (default) OR a live animal (mol/qo'y/ot). The two render
    # differently in the buyer UI (different badge, different cart logic — see SaleType + butcher service
    # offer) and price+stock semantics shift slightly: by_head sells per animal (head_count), by_weight
    # sells per live kg (quantity_kg). The yield % lets the buyer estimate finished meat from a live carcass.
    class SaleType(models.TextChoices):
        BY_WEIGHT = "BY_WEIGHT", _("By weight (kg)")     # raw meat AND live-by-weight animals
        BY_HEAD = "BY_HEAD", _("By head (per animal)")    # tirik chorva, donalab — uses head_count instead of kg

    is_live_animal = models.BooleanField(_("is live animal"), default=False, db_index=True,
                                         help_text=_("True = tirik chorva (live cow/sheep/horse); False = raw meat"))

    # v3.8 — orthogonal to `is_live_animal`. `animal_form` captures the physical form the listing ships:
    #   LIVE     — sold as a live animal only
    #   RAW_CUT  — sold as fresh ready meat (restaurants prefer this — no slaughtering needed)
    #   BOTH     — supplier can ship either way; buyer picks at checkout
    # Backfilled by migration: existing rows with is_live_animal=True become LIVE, others RAW_CUT.
    # The partners-app catalog UI lets the supplier pick this directly when creating a listing; the
    # buyer-app Servislar tab uses it as a filter facet.
    class AnimalForm(models.TextChoices):
        LIVE = "LIVE", _("Live animal")
        RAW_CUT = "RAW_CUT", _("Fresh ready meat (cut)")
        BOTH = "BOTH", _("Both live + cut")

    animal_form = models.CharField(_("animal form"), max_length=8, choices=AnimalForm.choices,
                                    default=AnimalForm.RAW_CUT, db_index=True)
    sale_type = models.CharField(_("sale type"), max_length=10, choices=SaleType.choices,
                                 default=SaleType.BY_WEIGHT,
                                 help_text=_("BY_HEAD = sold per animal; BY_WEIGHT = sold per kg (raw meat OR live by kg)"))
    # Estimated yield: how many kg of finished meat per kg of live weight (52-58% for cattle, 50-55% for sheep
    # per the PRD). 0 means "not applicable" (raw meat listings). UI shows it on live-animal cards so the
    # buyer can estimate finished-meat tonnage before committing.
    estimated_meat_yield_pct = models.PositiveSmallIntegerField(_("estimated meat yield %"), default=0,
                                                                help_text=_("Live-only: 0-100 (0 = N/A for raw meat). 55 means a 100kg animal yields ~55kg of finished meat"))
    # Filter facets — both nullable so raw meat listings can leave them blank.
    breed_type = models.CharField(_("breed"), max_length=80, blank=True, db_index=True,
                                  help_text=_("Hisor, Shved, Gissar etc. — live animals only; blank for raw meat"))
    head_count = models.PositiveIntegerField(_("head count"), default=0,
                                             help_text=_("Number of animals available — only used when sale_type=BY_HEAD"))
    # Per-head live weight (kg) for BY_HEAD listings. Lets the UI display "1 bosh ≈ 60kg" without forcing
    # the buyer to compute it. For BY_WEIGHT listings, quantity_kg is the source of truth and this is 0.
    live_weight_per_head_kg = models.DecimalField(_("live weight per head (kg)"), max_digits=8, decimal_places=2,
                                                  default=Decimal("0.00"),
                                                  validators=[MinValueValidator(Decimal("0.00"))],
                                                  help_text=_("Average live weight per animal for BY_HEAD listings"))

    # ---- Audit ------------------------------------------------------------------------------------
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="listings_created", editable=False)
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="listings_updated", editable=False)

    # django-simple-history — automatic row-level audit trail. Every save() creates a row in listings_historicallisting
    # tagged with the user from HistoryRequestMiddleware. Excludes high-churn fields (quantity_kg, updated_at) from
    # the diff to keep the history table compact when orders frequently decrement stock.
    history = HistoricalRecords(excluded_fields=["quantity_kg", "updated_at"])

    class Meta:
        verbose_name = _("product")
        verbose_name_plural = _("products")
        ordering = ("-created_at",)
        # Composite indexes drive the buyer's two hot query paths:
        #   (status, category) — "show me all ACTIVE beef listings"
        #   (market, status)   — "show me what THIS market currently has on sale"
        indexes = [
            models.Index(fields=("status", "category"), name="listing_status_category_idx"),
            models.Index(fields=("market", "status"), name="listing_market_status_idx"),
        ]
        # Slug is unique per-market — same slug "premium-mol" is fine across two different markets
        constraints = [
            models.UniqueConstraint(fields=("market", "slug"), name="uniq_market_slug",
                                    condition=models.Q(slug__gt="")),
        ]

    def __str__(self):
        label = self.name_uz or self.title or f"Listing #{self.pk}"
        return f"{label} ({self.quantity_kg}kg @ {self.price_per_kg}, {self.status})"

    def save(self, *args, **kwargs):
        """Auto-fill slug from name_uz on first save. Slug uniqueness is per-market (enforced by UniqueConstraint)."""
        from django.utils.text import slugify
        if not self.slug and self.name_uz:
            self.slug = slugify(self.name_uz)[:140]
        super().save(*args, **kwargs)


class PriceHistory(TimeStampedModel):
    """Append-only log of every price change on a Listing. Populated by a post_save signal in apps/listings/signals.py.

    Why a separate table instead of relying on django-simple-history? PriceHistory is queryable as first-class data:
      • The mobile app can show a "price dropped 5%" badge by reading the latest 2 rows for a listing.
      • Analytics queries ("avg price change per category last month") run cleanly off this narrow table.
      • django-simple-history's history table is wider + more general — fine for audit, slower for aggregates.

    Both can coexist. Use this for product-facing price intelligence; use simple-history for audit/compliance."""

    listing = models.ForeignKey("listings.Listing", on_delete=models.CASCADE,
                                related_name="price_history", db_index=True)
    old_price = models.DecimalField(_("old price"), max_digits=10, decimal_places=2)
    new_price = models.DecimalField(_("new price"), max_digits=10, decimal_places=2)
    # changed_by is set from request.user in the signal — null when the change happens outside a request
    # (e.g. shell commands, bulk admin actions, data migrations).
    changed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
                                   related_name="price_changes_made")

    class Meta:
        verbose_name = _("price history entry")
        verbose_name_plural = _("price history")
        ordering = ("-created_at",)
        # Index for the "latest price change per listing" query — common on the mobile detail screen
        indexes = [models.Index(fields=("listing", "-created_at"), name="price_hist_listing_recent_idx")]

    def __str__(self): return f"#{self.listing_id}: {self.old_price} → {self.new_price}"


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
