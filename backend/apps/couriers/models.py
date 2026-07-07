"""Courier + Delivery — v3.9.14 delivery system foundation.

Two concerns modeled here:

    CourierProfile — the delivery driver's app-facing shape (vehicle, availability, ratings,
    earnings totals). Created lazily on first login of a role=COURIER user. Suppliers who tick
    `supplier_delivers` on a listing get an implicit COURIER hat via a signal — they retain their
    SUPPLIER role but gain a CourierProfile so the delivery-app UI works for them.

    Delivery — one row per assigned dispatch. Links Order → Courier + carries the courier-facing
    state (assigned / picked-up / arrived / delivered / cancelled), the drop-off signature (photo
    proof), and cash-collected amount for cash-on-delivery orders.

State model (courier's app):
    ASSIGNED     — order landed on courier's queue (auto or self-claimed)
    PICKED_UP    — courier picked package up from supplier / market
    EN_ROUTE     — driving to the drop-off address
    ARRIVED      — parked, waiting for buyer contact
    DELIVERED    — courier marked handover done (flips Order to DELIVERED_PENDING_CONFIRMATION)
    CANCELLED    — driver canceled (e.g. buyer no-show); dispatcher re-routes

The buyer's OrderConfirmDeliveryView is what flips the parent Order into DELIVERED — this Delivery
row's DELIVERED state is the courier's side; the two states are distinct on purpose so a courier
can't self-confirm receipt.
"""
from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


def _courier_photo_path(instance, filename):
    return f"couriers/{instance.user_id}/{filename}"


def _delivery_proof_path(instance, filename):
    return f"deliveries/{instance.pk or 'new'}/{filename}"


class CourierProfile(TimeStampedModel):
    """Delivery driver profile — one-to-one with User (role=COURIER, or a SUPPLIER acting as their
    own courier). Populated on first courier-app login."""

    class VehicleKind(models.TextChoices):
        BIKE = "BIKE", _("Bike / motorbike")
        CAR = "CAR", _("Car")
        VAN = "VAN", _("Van / small truck")
        REFRIGERATOR = "REFRIGERATOR", _("Refrigerated van (cold-chain)")
        CHORVA_TAXI = "CHORVA_TAXI", _("Chorva-Taksi (live animal transport)")

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                related_name="courier_profile", db_index=True)
    full_name = models.CharField(_("full name"), max_length=150, blank=True)
    photo = models.ImageField(_("photo"), upload_to=_courier_photo_path, null=True, blank=True)

    vehicle_kind = models.CharField(_("vehicle"), max_length=16,
                                     choices=VehicleKind.choices, default=VehicleKind.BIKE)
    vehicle_plate = models.CharField(_("license plate"), max_length=20, blank=True)

    # F1 — availability toggle. Only ONLINE couriers get auto-assigned new deliveries.
    is_online = models.BooleanField(_("online / accepting jobs"), default=False, db_index=True)

    # Denormalised ratings + lifetime earnings (updated by signals). Cheap read on the courier's
    # dashboard tiles.
    rating_avg = models.DecimalField(_("rating average"), max_digits=3, decimal_places=2, default=0)
    rating_count = models.PositiveIntegerField(_("rating count"), default=0)
    lifetime_deliveries = models.PositiveIntegerField(_("lifetime deliveries"), default=0)
    lifetime_earnings_uzs = models.PositiveBigIntegerField(_("lifetime earnings (soum)"), default=0)

    class Meta:
        verbose_name = _("courier profile")
        verbose_name_plural = _("courier profiles")
        ordering = ("-created_at",)

    def __str__(self): return f"Courier {self.user.email} ({self.vehicle_kind})"


class Delivery(TimeStampedModel):
    """One dispatch of one Order to one Courier. Immutable Order/Courier pair once created."""

    class Status(models.TextChoices):
        ASSIGNED = "ASSIGNED", _("Assigned")
        PICKED_UP = "PICKED_UP", _("Picked up")
        EN_ROUTE = "EN_ROUTE", _("En route")
        ARRIVED = "ARRIVED", _("Arrived at drop-off")
        DELIVERED = "DELIVERED", _("Delivered (courier-side)")
        CANCELLED = "CANCELLED", _("Cancelled")

    order = models.OneToOneField("orders.Order", on_delete=models.CASCADE,
                                  related_name="delivery", db_index=True)
    courier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                                 related_name="deliveries", db_index=True)
    status = models.CharField(_("status"), max_length=16,
                              choices=Status.choices, default=Status.ASSIGNED, db_index=True)

    # Cash-on-delivery — the courier records what they collected on the doorstep. Enables the
    # end-of-shift reconciliation the platform's finance team runs against provider settlements.
    cash_collected_uzs = models.PositiveBigIntegerField(_("cash collected (soum)"), default=0)

    # Photo proof of delivery — courier snaps a shot of the package at the drop-off (mirrors
    # DoorDash / Wolt "photo confirmation" for contactless drops).
    proof_photo = models.ImageField(_("proof photo"), upload_to=_delivery_proof_path,
                                     null=True, blank=True)

    # Denormalised courier earnings for THIS delivery — snapshotted at assignment so a later
    # base-rate change doesn't retroactively rewrite what the courier expects.
    payout_uzs = models.PositiveBigIntegerField(_("courier payout (soum)"), default=0)

    # Rating the buyer left after DELIVERED. Nullable so unrated deliveries aren't counted.
    buyer_rating = models.PositiveSmallIntegerField(_("buyer rating"), null=True, blank=True,
                                                     validators=[MinValueValidator(1), MaxValueValidator(5)])

    # Timestamps for the courier-side lifecycle — powers the earnings tracker (day/week/month).
    picked_up_at = models.DateTimeField(_("picked up at"), null=True, blank=True)
    delivered_at = models.DateTimeField(_("delivered at"), null=True, blank=True)

    class Meta:
        verbose_name = _("delivery")
        verbose_name_plural = _("deliveries")
        ordering = ("-created_at",)
        indexes = [
            # Courier's active-queue query hits this: /partner/courier/queue/ = "MY deliveries not
            # yet DELIVERED/CANCELLED, ordered by created_at asc".
            models.Index(fields=("courier", "status")),
        ]

    def __str__(self): return f"Delivery #{self.pk} of Order #{self.order_id} → {self.courier.email}"
