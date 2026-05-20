"""Signals — Listing price-change logging + ListingPhoto async resize enqueue.

Listing:
  • pre_save captures the OLD row's price (DB-side) into instance._previous_price
  • post_save compares it against the new price; if different, a PriceHistory row is appended
  • request-coupling: views that hand-set instance._actor=request.user let us attribute the change
  • Skip the log: instance._skip_price_history=True (used by migrations + seed commands)

ListingPhoto:
  • post_save enqueues the Celery resize task. The task downsizes to max 2000px + converts to WebP, then re-saves
    the row with instance._skip_resize=True to prevent the signal from re-enqueueing itself.
"""
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver

from .models import Listing, ListingPhoto, PriceHistory


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


@receiver(post_save, sender=ListingPhoto)
def _enqueue_photo_resize(sender, instance, created, **kwargs):
    """After a ListingPhoto save, enqueue the async resize task. The task itself sets _skip_resize=True before
    saving the optimized file, so this signal fires once per upload (not in a loop on every re-save)."""
    if getattr(instance, "_skip_resize", False) or not instance.image:
        return
    # Already-WebP files don't need re-processing — saves a worker round-trip on subsequent metadata edits.
    if instance.image.name.lower().endswith(".webp"):
        return
    # Import inline to avoid a circular import at app startup (tasks.py imports models, signals.py imports tasks).
    from .tasks import resize_listing_photo
    # transaction.on_commit would be more correct in a tight transaction, but post_save fires AFTER the commit
    # for our use cases, so delay() is fine. If we ever wrap photo creation in atomic(), wrap this in on_commit.
    resize_listing_photo.delay(instance.pk)
