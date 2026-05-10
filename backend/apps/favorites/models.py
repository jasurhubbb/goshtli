"""Favorite — user-saved listing. Composite unique on (user, listing) keeps heart-icon idempotent.

Implemented as a separate pivot table (not a Django M2M on Listing) so we can attach extra fields later — e.g.
'reminded_at' for inventory-alerts feature.
"""
from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel
from apps.listings.models import Listing


class Favorite(TimeStampedModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="favorites", db_index=True)
    listing = models.ForeignKey(Listing, on_delete=models.CASCADE, related_name="favorited_by", db_index=True)

    class Meta:
        verbose_name = _("favorite")
        verbose_name_plural = _("favorites")
        ordering = ("-created_at",)
        # Composite unique — toggling heart on/off uses get_or_create + delete so duplicates are impossible by design
        constraints = [models.UniqueConstraint(fields=("user", "listing"), name="uniq_favorite_user_listing")]

    def __str__(self): return f"{self.user.email} ♥ {self.listing.title}"
