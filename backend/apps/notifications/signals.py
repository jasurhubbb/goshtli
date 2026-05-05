"""Auto-create notifications on key domain events. Handlers stay tiny and idempotent — heavy logic lives in services."""
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from apps.orders.models import Order
from apps.suppliers.models import SupplierProfile
from .models import Notification


# ---------- Supplier verification ----------

@receiver(pre_save, sender=SupplierProfile)
def _track_verification_change(sender, instance, **kwargs):
    """Stash the previous is_verified value so the post_save handler can detect a False→True transition."""
    if not instance.pk: instance._was_verified = False; return
    try: instance._was_verified = SupplierProfile.objects.get(pk=instance.pk).is_verified
    except SupplierProfile.DoesNotExist: instance._was_verified = False


@receiver(post_save, sender=SupplierProfile)
def _notify_supplier_verified(sender, instance, created, **kwargs):
    # Only fire when verification actually flips from False → True; ignore initial creation + no-op saves
    if created or instance.is_verified is False or getattr(instance, "_was_verified", True): return
    Notification.objects.create(user=instance.user, kind=Notification.Kind.SUPPLIER_VERIFIED,
        title="Account verified",
        message="Your supplier account is now verified — you can create listings.",
        link="/listings/new")


# ---------- Order events ----------

@receiver(pre_save, sender=Order)
def _track_status_change(sender, instance, **kwargs):
    """Capture previous status for the post_save side so we can detect transitions vs initial create."""
    if not instance.pk: instance._previous_status = None; return
    try: instance._previous_status = Order.objects.get(pk=instance.pk).status
    except Order.DoesNotExist: instance._previous_status = None


@receiver(post_save, sender=Order)
def _notify_order_event(sender, instance, created, **kwargs):
    """Branch on creation vs status change — supplier learns about new orders, buyer learns about status changes/cancellations."""
    if created:
        # New order → notify the supplier whose listing it's against
        Notification.objects.create(user=instance.listing.supplier, kind=Notification.Kind.ORDER_PLACED,
            title=f"New order #{instance.pk}",
            message=f"{instance.buyer.email} ordered {instance.quantity_kg}kg of {instance.listing.title}.",
            link=f"/orders/{instance.pk}")
        return

    prev = getattr(instance, "_previous_status", None)
    if prev is None or prev == instance.status: return  # no transition; nothing to notify

    if instance.status == Order.Status.CANCELLED:
        # Cancellation cuts both ways — notify whichever party didn't initiate the cancel. We can't know who initiated
        # at signal time, so we send to both. The UI deduplicates by per-user feed scoping.
        for u in (instance.buyer, instance.listing.supplier):
            Notification.objects.create(user=u, kind=Notification.Kind.ORDER_CANCELLED,
                title=f"Order #{instance.pk} cancelled",
                message=f"Stock for {instance.listing.title} has been restored.",
                link=f"/orders/{instance.pk}")
    else:
        # Forward transition (CONFIRMED/PROCESSING/IN_TRANSIT/DELIVERED) — notify the buyer who's tracking the order
        Notification.objects.create(user=instance.buyer, kind=Notification.Kind.ORDER_STATUS_CHANGED,
            title=f"Order #{instance.pk}: {instance.get_status_display()}",
            message=f"Your order for {instance.listing.title} is now {instance.get_status_display().lower()}.",
            link=f"/orders/{instance.pk}")
