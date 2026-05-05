"""Listing — meat stock entry. Buyers can order only from ACTIVE listings; quantity is mutated atomically by the orders service."""
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

    # FK is User (not SupplierProfile) per database-design wording — verification check happens in the service layer
    supplier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                 related_name="listings", limit_choices_to={"role": "SUPPLIER"}, db_index=True)
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

    class Meta:
        verbose_name = _("listing")
        verbose_name_plural = _("listings")
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("status", "meat_type", "location"))]  # supports common filter combinations

    def __str__(self): return f"{self.title} ({self.quantity_kg}kg @ {self.price_per_kg}, {self.status})"
