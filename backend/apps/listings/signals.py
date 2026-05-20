"""Signals — runs on every Listing save to detect price changes and log them to PriceHistory.

The pattern:
  • pre_save captures the OLD row's price (DB-side) into instance._previous_price
  • post_save compares it against the new price; if different, a PriceHistory row is appended
  • request-coupling: views that hand-set instance._actor=request.user let us attribute the change

Skipping the log: pass `_skip_price_history=True` on the instance to suppress logging (used by data migrations
and seed commands so they don't fill PriceHistory with bootstrap noise).
"""
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver

from .models import Listing, PriceHistory


@receiver(pre_save, sender=Listing)
def _capture_old_price(sender, instance, **kwargs):
    """Stash the DB-side price (before this save commits) so post_save can compare. Reads add ~1 query per save,
    which is negligible vs. how rarely listings are mutated."""
    if not instance.pk:
        instance._previous_price = None  # New row → no history to log
        return
    try:
        instance._previous_price = sender.objects.only("price_per_kg").get(pk=instance.pk).price_per_kg
    except sender.DoesNotExist:
        instance._previous_price = None


@receiver(post_save, sender=Listing)
def _log_price_change(sender, instance, created, **kwargs):
    """Append a PriceHistory row when the price actually changed. Skip on creation (no old price exists),
    and skip when the caller opted out via instance._skip_price_history."""
    if created or getattr(instance, "_skip_price_history", False):
        return
    old = getattr(instance, "_previous_price", None)
    new = instance.price_per_kg
    if old is None or old == new:
        return
    PriceHistory.objects.create(
        listing=instance,
        old_price=old,
        new_price=new,
        # _actor is set by views/admin where the request.user is known; falls back to None for shell + migrations
        changed_by=getattr(instance, "_actor", None),
    )
