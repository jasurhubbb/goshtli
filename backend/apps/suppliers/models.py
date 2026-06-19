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
    """One-to-one with User — opt-in. is_verified gates listing creation; only admin can flip it.

    v3.8 — extended with the wizard fields collected during the partners-app Supplier onboarding flow:
    personal full_name, animal-form delivery_modes, self-delivery capability, lat/lng for distance-based
    sorting on the buyer-side, F1 quiet-hours toggle, and denormalised ratings.
    """
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

    # ---- v3.8 partner-app wizard fields ----
    # Personal name of the operator; separate from User.full_name so the same human can have buyer-side
    # full_name = "Jasur" while business-side full_name on supplier card reads "Jasur Mamarasulov".
    full_name = models.CharField(_("operator full name"), max_length=150, blank=True,
                                  help_text=_("From Supplier wizard p2 — printed on the supplier card."))

    # GPS for distance sorting on the buyer-app catalog + Servislar tab. Wizard p5 sets these.
    lat = models.DecimalField(_("latitude"), max_digits=9, decimal_places=6, null=True, blank=True)
    lng = models.DecimalField(_("longitude"), max_digits=9, decimal_places=6, null=True, blank=True)

    # JSON list of animal codes from VALID_ANIMAL_CODES — what the supplier carries. Used as a quick
    # filter on the buyer-app home grid + Servislar tab.
    animals_supported = models.JSONField(_("animals supported"), default=list,
                                          help_text=_("List of animal codes from MOL/QOY/ECHKI/OT/TOVUQ."))

    # Per-animal delivery modes from wizard p4:
    #   {"MOL": ["LIVE","CUT"], "QOY": ["CUT"]}  ← MOL both live & ready meat, QOY only cut meat
    # Buyer-app filter on the buyer side uses this to surface "restaurants need ready-cut" → match.
    delivery_modes = models.JSONField(_("delivery modes per animal"), default=dict,
                                       help_text=_("Per-animal map: {animal_code: [LIVE|CUT, ...]}."))

    # F1 — Open/Closed quiet-hours toggle. When False, the supplier's listings are filtered out of buyer
    # search and incoming orders auto-reject.
    is_open_now = models.BooleanField(_("open for orders now"), default=True, db_index=True)

    # Self-delivery capability — answered on wizard p6. If True, the supplier owns delivery for their
    # own listings; otherwise the marketplace dispatches via /apps/delivery/ vehicle quote.
    self_delivers = models.BooleanField(_("self-delivers own orders"), default=False)
    vehicle_types = models.JSONField(_("vehicle types"), default=list,
                                      help_text=_("['REFRIGERATOR'|'CHORVA_TAXI'] — only when self_delivers."))
    vehicle_plate = models.CharField(_("vehicle plate number"), max_length=20, blank=True)

    # Optional Telegram handle — drives F9 "Telegram orqali bog'lanish" button.
    telegram_username = models.CharField(_("telegram username"), max_length=64, blank=True)

    # Denormalised ratings (updated by signal in apps.reviews when a new review lands).
    rating_avg = models.DecimalField(_("rating average"), max_digits=3, decimal_places=2, default=0)
    rating_count = models.PositiveIntegerField(_("rating count"), default=0)

    class Meta:
        verbose_name = _("supplier profile")
        verbose_name_plural = _("supplier profiles")

    def __str__(self): return f"{self.business_name or self.user.email} (verified={self.is_verified})"
