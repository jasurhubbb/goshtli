"""Review — one rating per delivered order. Anti-abuse: only the buyer of a DELIVERED order can leave one.

Denormalized supplier_id on the row so we can index aggregates (avg rating per supplier) without an Order join.
"""
from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel
from apps.orders.models import Order


class Review(TimeStampedModel):
    # OneToOne with Order — enforces one review per order at the DB level (no race-condition double-review)
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name="review")
    # Denormalized buyer + supplier — lets us answer "all reviews this supplier got" without joining orders
    buyer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                              related_name="reviews_written", db_index=True)
    supplier = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                 related_name="reviews_received", db_index=True)
    rating = models.PositiveSmallIntegerField(_("rating"),
                                              validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(_("comment"), blank=True)

    class Meta:
        verbose_name = _("review")
        verbose_name_plural = _("reviews")
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("supplier", "-created_at"))]  # supplier-profile reviews query

    def __str__(self): return f"{self.rating}★ by {self.buyer.email} → {self.supplier.email}"
