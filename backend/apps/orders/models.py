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
        # State machine: PENDING is the only entry state; DELIVERED & CANCELLED are terminal
        PENDING = "PENDING", _("Pending")
        CONFIRMED = "CONFIRMED", _("Confirmed")
        PROCESSING = "PROCESSING", _("Processing")
        IN_TRANSIT = "IN_TRANSIT", _("In transit")
        DELIVERED = "DELIVERED", _("Delivered")
        CANCELLED = "CANCELLED", _("Cancelled")

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
    status = models.CharField(_("status"), max_length=12, choices=Status.choices, default=Status.PENDING, db_index=True)

    class Meta:
        verbose_name = _("order")
        verbose_name_plural = _("orders")
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("status", "buyer")), models.Index(fields=("status", "listing"))]

    def __str__(self): return f"Order #{self.pk} — {self.buyer.email} × {self.quantity_kg}kg ({self.status})"

    # Convenience used by permissions / state machine — keeps "is this still cancellable?" readable in views
    @property
    def is_terminal(self): return self.status in (self.Status.DELIVERED, self.Status.CANCELLED)
