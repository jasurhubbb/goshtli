"""Order — buyer's purchase of a listing. Status transitions are guarded by the service layer (orders/services.py)."""
from decimal import Decimal
from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel
from apps.listings.models import Listing


class Order(TimeStampedModel):
    class Status(models.TextChoices):
        # State machine per PRD v2 §4: PENDING is the only entry state; DELIVERED & CANCELLED are terminal.
        # PROCESSING_BUTCHER is the legacy state (v3.6) for butcher-on-the-spot orders.
        # v3.8 inserts AWAITING_QASSOB BETWEEN CONFIRMED and PROCESSING_BUTCHER for the dispatch window —
        # an order with butcher service requested waits in this state for a qassob to claim it via the
        # partner-app inbox. The supplier confirms (CONFIRMED) → marketplace fans the job out → first
        # qassob to tap Accept moves it to PROCESSING_BUTCHER and `assigned_qassob` is stamped.
        PENDING = "PENDING", _("Pending")
        CONFIRMED = "CONFIRMED", _("Confirmed")
        PROCESSING = "PROCESSING", _("Processing")
        AWAITING_QASSOB = "AWAITING_QASSOB", _("Awaiting qassob")
        PROCESSING_BUTCHER = "PROCESSING_BUTCHER", _("At butcher (slaughter & cut)")
        IN_TRANSIT = "IN_TRANSIT", _("In transit")
        # v3.9.14 — the courier / self-delivering supplier marks "yetkazildi" via the delivery app,
        # BUT the order isn't truly closed until the buyer taps "Buyurtmani qabul qildim" in their
        # app. This state is the confirmation window in between. Prevents disputes about whether a
        # package actually arrived (mirrors Uzum Tezkor / Wolt behavior).
        DELIVERED_PENDING_CONFIRMATION = "DELIVERED_PENDING_CONFIRMATION", _("Delivered — awaiting buyer confirmation")
        DELIVERED = "DELIVERED", _("Delivered")
        CANCELLED = "CANCELLED", _("Cancelled")

    # ---- v3.6 Delivery (Yetkazib berish) — per PRD v2 §3 -----------------------------------------
    # Delivery is its own page in the buyer flow (Cart → Delivery → Checkout/Pay → Orders). The two
    # vehicle types are dictated by the cart contents:
    #   REFRIGERATOR  — raw meat OR (live + butcher requested) → cold-chain 0°C..+4°C
    #   CHORVA_TAXI   — live + butcher declined → open/bortli truck for live animal transport
    class VehicleType(models.TextChoices):
        REFRIGERATOR = "REFRIGERATOR", _("Refrigerator (cold-chain)")
        CHORVA_TAXI = "CHORVA_TAXI", _("Chorva-Taksi (live animal)")

    # Three fixed delivery windows per PRD: 06:00-09:00 (early-morning to'y oshlari slot), 09:00-13:00, 13:00-18:00
    class TimeSlot(models.TextChoices):
        SLOT_0609 = "SLOT_0609", _("06:00 – 09:00")
        SLOT_0913 = "SLOT_0913", _("09:00 – 13:00")
        SLOT_1318 = "SLOT_1318", _("13:00 – 18:00")

    # v3.5 — payment state is a SEPARATE axis from the order-fulfilment status (above) because Payme's
    # webhook fires before the supplier acknowledges. Order is CONFIRMED by the supplier; PaymentStatus
    # moves through PENDING → PAID (or FAILED/REFUNDED) driven by the payment provider's webhook.
    class PaymentStatus(models.TextChoices):
        UNPAID = "UNPAID", _("Unpaid")                  # order placed, no payment attempt yet
        PENDING = "PENDING", _("Pending")               # pay-link generated; buyer is on the provider's page
        PAID = "PAID", _("Paid")                         # webhook confirmed funds settled
        FAILED = "FAILED", _("Failed")                   # provider rejected (insufficient funds, 3DS fail, expired)
        REFUNDED = "REFUNDED", _("Refunded")             # full or partial refund issued via provider

    # Unified user model — any authenticated user can place an order. PROTECT on listing so deleting a listing with
    # attached orders fails loudly instead of orphaning history.
    buyer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                              related_name="orders", db_index=True)
    listing = models.ForeignKey(Listing, on_delete=models.PROTECT, related_name="orders", db_index=True)
    quantity_kg = models.DecimalField(_("quantity (kg)"), max_digits=10, decimal_places=2,
                                      validators=[MinValueValidator(Decimal("0.01"))])
    # total_price snapshot — computed at creation so later price changes on the listing do NOT affect existing orders
    total_price = models.DecimalField(_("total price"), max_digits=12, decimal_places=2,
                                      validators=[MinValueValidator(Decimal("0.00"))])
    delivery_address = models.TextField(_("delivery address"))
    notes = models.TextField(_("notes"), blank=True)
    status = models.CharField(_("status"), max_length=32, choices=Status.choices, default=Status.PENDING, db_index=True)

    # ---- v3.5 payment fields ----
    payment_status = models.CharField(_("payment status"), max_length=10,
                                      choices=PaymentStatus.choices,
                                      default=PaymentStatus.UNPAID, db_index=True)
    # Identifier of which provider/adapter we used (e.g. "payme", "click", "mock"). Lets us scale to
    # multiple providers later without backfilling rows. Set on first /pay/ call.
    payment_provider = models.CharField(_("payment provider"), max_length=20, blank=True)
    # The provider's transaction id (Payme's _id, Click's transaction_id). Stored so the webhook can
    # look up which Order a callback belongs to without trusting the order_id in the callback body.
    payment_provider_tx_id = models.CharField(_("payment provider tx id"), max_length=128, blank=True,
                                              db_index=True)
    # Cached pay URL the mobile app opens in the WebView. Regenerated on retry — providers' URLs expire.
    payment_url = models.URLField(_("payment URL"), max_length=2048, blank=True)

    # ---- v3.6 delivery + butcher service fields ----
    # All optional at the DB layer (blank/0 defaults) so legacy orders pre-PRD-v2 still load. Validated as
    # required by OrderCreateSerializer for new orders going through the delivery page.
    delivery_vehicle_type = models.CharField(_("delivery vehicle type"), max_length=16,
                                             choices=VehicleType.choices, blank=True)
    delivery_time_slot = models.CharField(_("delivery time slot"), max_length=12,
                                          choices=TimeSlot.choices, blank=True)
    delivery_distance_km = models.DecimalField(_("delivery distance (km)"), max_digits=8, decimal_places=2,
                                                default=Decimal("0.00"))
    delivery_lat = models.DecimalField(_("delivery latitude"), max_digits=9, decimal_places=6,
                                       null=True, blank=True)
    delivery_lng = models.DecimalField(_("delivery longitude"), max_digits=9, decimal_places=6,
                                       null=True, blank=True)
    delivery_price = models.DecimalField(_("delivery price"), max_digits=12, decimal_places=2,
                                          default=Decimal("0.00"))
    # Butcher (Qassob / Service Hub) — buyer ticks "yes" on the cart when at least one live-animal item.
    # The fee is fixed per the active service-hub rate card (no per-order pricing for v1).
    butcher_service_requested = models.BooleanField(_("butcher service requested"), default=False)
    butcher_service_fee = models.DecimalField(_("butcher service fee"), max_digits=12, decimal_places=2,
                                              default=Decimal("0.00"))

    # ---- v3.8 qassob assignment (only set when butcher_service_requested=True) -------------------
    # Set when a qassob taps "Accept" on the partner-app inbox while order.status=AWAITING_QASSOB.
    # SET_NULL so cancelling a qassob's account doesn't cascade-delete orders. The buyer's order detail
    # shows "Qassob: <name>" when this is set.
    assigned_qassob = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                          null=True, blank=True, related_name="qassob_orders",
                                          db_index=True)
    # v3.9.15 — buyer's PREFERRED qassob (chosen from the Servislar tab or listing detail when a live-
    # animal order is placed). Distinct from `assigned_qassob` because the qassob still has to accept
    # the job — until then, other qassobs won't see it in their inbox (soft-reservation for 60s window
    # handled in orders/services.py). If the preferred qassob rejects, the order fans out to all
    # matching qassobs and `preferred_qassob` remains as a historical hint (buyer told us who they
    # wanted) while `assigned_qassob` fills with whoever eventually accepts.
    preferred_qassob = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                                          null=True, blank=True, related_name="preferred_qassob_orders",
                                          db_index=True)
    # Snapshot payout — what we'll pay the qassob when the order completes. Frozen at assignment time so
    # later rate-card changes don't retroactively rewrite history. F10 income export reads this.
    qassob_payout = models.DecimalField(_("qassob payout"), max_digits=12, decimal_places=2,
                                          default=Decimal("0.00"))

    class Meta:
        verbose_name = _("order")
        verbose_name_plural = _("orders")
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("status", "buyer")), models.Index(fields=("status", "listing"))]

    def __str__(self): return f"Order #{self.pk} — {self.buyer.email} × {self.quantity_kg}kg ({self.status})"

    # Convenience used by permissions / state machine — keeps "is this still cancellable?" readable in views
    @property
    def is_terminal(self): return self.status in (self.Status.DELIVERED, self.Status.CANCELLED)
