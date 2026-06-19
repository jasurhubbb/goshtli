"""Qassob (butcher) + slaughterhouse (qushxona) profile model. Mirrors SupplierProfile pattern.

Created when a Qassob completes onboarding (POST /api/v1/qassobs/me/). Until `is_verified` is flipped
by an admin (after KYC review), the qassob is invisible to buyers' Servislar tab and cannot be
assigned slaughter jobs from the partner inbox.
"""
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


def qassob_photo_path(instance, filename):
    """Per-qassob folder so admin/storage cleanup is one-folder-delete on profile removal."""
    return f"qassobs/{instance.user_id}/{filename}"


# Animal-code shared with frontend + Listing. Kept here as the canonical list so a future addition
# (qushlar / tovuq? balıq?) bumps in one place. Mobile + buyer-app both reference these strings literally.
ANIMAL_CHOICES = (
    ("MOL", _("Mol (Cattle)")),
    ("QOY", _("Qo'y (Sheep)")),
    ("ECHKI", _("Echki (Goat)")),
    ("OT", _("Ot (Horse)")),
)
VALID_ANIMAL_CODES = {code for code, _label in ANIMAL_CHOICES}


class QassobProfile(TimeStampedModel):
    """One row per qassob user. Created lazily on first POST /qassobs/me/ from the partners app's
    onboarding wizard. `is_verified` is admin-only and gates visibility on the buyer-app Servislar tab
    + assignment to slaughter jobs in the partner inbox."""

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                 related_name="qassob_profile", db_index=True)

    # ---- Onboarding wizard fields ----
    full_name = models.CharField(_("full name"), max_length=150,
                                  help_text=_("Wizard p3 — overrides User.full_name on the buyer-facing card."))
    years_experience = models.PositiveSmallIntegerField(
        _("years of experience"),
        validators=[MinValueValidator(0), MaxValueValidator(80)],
        help_text=_("Wizard p2 — wheel picker 0-50. Used as a trust signal on the Servislar card."))

    # Location — auto-detected at signup via geolocator + reverse-geocoded; manually adjustable later via
    # PATCH /qassobs/me/. `address` is free-form text the buyer reads; lat/lng power the radius filter on
    # the Servislar tab so a buyer in Yunusobod sees nearby qassobs first.
    region = models.CharField(_("region"), max_length=100,
                              help_text=_("Reverse-geocoded from lat/lng on signup."))
    address = models.TextField(_("street address"))
    lat = models.DecimalField(_("latitude"), max_digits=9, decimal_places=6, null=True, blank=True)
    lng = models.DecimalField(_("longitude"), max_digits=9, decimal_places=6, null=True, blank=True)
    service_radius_km = models.PositiveSmallIntegerField(
        _("service radius (km)"), default=15,
        validators=[MinValueValidator(1), MaxValueValidator(200)],
        help_text=_("How far the qassob is willing to travel for live-animal pickup."))

    # Which animals this qassob handles. JSON list of codes from VALID_ANIMAL_CODES. Validated in the
    # serializer before save — DB layer trusts the validated payload.
    animals_supported = models.JSONField(_("animals supported"), default=list,
                                          help_text=_("List of animal codes — subset of MOL/QOY/ECHKI/OT."))

    # `is_slaughterhouse` separates the buyer-app Servislar tab into TWO sections:
    #    Qassoblar             — pure butchers, take pre-killed animals or work at qushxona
    #    Qushxona xizmatlari   — qassobs with their own kill-floor (slaughter on-site)
    # The wizard sets this via "Qushxonangiz bormi?" Ha/Yo'q toggle (p6).
    is_slaughterhouse = models.BooleanField(_("has slaughterhouse (qushxona)"), default=False, db_index=True)

    # F8 — capacity calendar. Daily cap on # of animals the qassob can handle. Buyers picking slots in
    # the buyer app see closed days greyed out when the day is fully booked.
    daily_capacity_head = models.PositiveSmallIntegerField(
        _("daily capacity (heads)"), default=10,
        validators=[MinValueValidator(1), MaxValueValidator(200)])

    # Shopfront photo. Optional at wizard time (p8 can be skipped). When R2 storage is configured the
    # file lands in Cloudflare; otherwise it falls back to the persistent /app/media volume on Railway.
    photo = models.ImageField(_("workplace photo"), upload_to=qassob_photo_path, null=True, blank=True)

    # Contact preferences
    phone_visible = models.BooleanField(_("show phone publicly"), default=True,
                                         help_text=_("If False, buyers contact via in-app chat only."))
    telegram_username = models.CharField(_("telegram username"), max_length=64, blank=True,
                                          help_text=_("Optional — enables the 'Telegram orqali bog'lanish' button."))

    # F1 — Open / Closed quiet-hours toggle. When False, qassob's listings (none — qassobs don't list
    # products; this is for SupplierProfile too) and Servislar-tab card show as "Hozir yopiq". Auto-reject
    # incoming jobs in the partner inbox.
    is_open_now = models.BooleanField(_("open for jobs now"), default=True, db_index=True)

    # Denormalised ratings (updated by signal in apps.reviews when a new review lands) — avoids JOIN on
    # every Servislar-tab load. Mobile sees `rating_avg` + `rating_count` directly.
    rating_avg = models.DecimalField(_("rating average"), max_digits=3, decimal_places=2, default=0)
    rating_count = models.PositiveIntegerField(_("rating count"), default=0)

    # KYC gate. Set by signal in apps.accounts when ALL required KYCDocument rows (PASSPORT +
    # BUSINESS_LICENSE) reach is_approved=True. Buyers see only verified qassobs.
    is_verified = models.BooleanField(_("verified by admin"), default=False, db_index=True)

    class Meta:
        verbose_name = _("qassob profile")
        verbose_name_plural = _("qassob profiles")
        ordering = ("-rating_avg", "-created_at")
        indexes = [
            # Buyer's Servislar tab does GET /qassobs/?region=...&is_verified=true ordered by rating —
            # this composite covers it.
            models.Index(fields=("is_verified", "region", "-rating_avg"), name="qassob_search_idx"),
        ]

    def __str__(self): return f"Qassob {self.full_name} ({self.user.email})"
