"""Auto-create notifications on key domain events. Each notification ALSO fires a Firebase push so the phone wakes
up even when the app is closed. push is best-effort — if FCM is down or unconfigured, the in-app notification still
lands, and the user sees it next time they open the app.
"""
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from apps.orders.models import Order
from apps.suppliers.models import SupplierProfile
from .fcm import send_to_user
from .models import Notification


def _notify(user, kind, title, message, link, extra=None):
    """Create an in-app Notification row AND fire a push. Centralized so both rails stay in sync.

    v3.9.12 — passes `kind` (Notification.Kind value) + optional `extra` dict to FCM so the client
    can route on the payload without parsing the link path. `extra` typically carries the entity id
    that changed (order_id, conversation_id) so the mobile can invalidate exactly the right cache."""
    Notification.objects.create(user=user, kind=kind, title=title, message=message, link=link)
    send_to_user(user, title=title, body=message, link=link, kind=kind, extra=extra or {})


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
    _notify(instance.user, Notification.Kind.SUPPLIER_VERIFIED,
        "Account verified",
        "Your supplier account is now verified — you can create listings.",
        "/listings/new")


# ---------- Order events ----------

@receiver(pre_save, sender=Order)
def _track_status_change(sender, instance, **kwargs):
    """Capture previous status for the post_save side so we can detect transitions vs initial create."""
    if not instance.pk: instance._previous_status = None; return
    try: instance._previous_status = Order.objects.get(pk=instance.pk).status
    except Order.DoesNotExist: instance._previous_status = None


@receiver(post_save, sender=Order)
def _notify_order_event(sender, instance, created, **kwargs):
    """Branch on creation vs status change — supplier learns about new orders, buyer learns about status changes."""
    if created:
        _notify(instance.listing.supplier, Notification.Kind.ORDER_PLACED,
            f"New order #{instance.pk}",
            f"{instance.buyer.email} ordered {instance.quantity_kg}kg of {instance.listing.name_uz}.",
            f"/orders/{instance.pk}",
            extra={"order_id": instance.pk})
        return

    prev = getattr(instance, "_previous_status", None)
    if prev is None or prev == instance.status: return  # no transition; nothing to notify

    if instance.status == Order.Status.CANCELLED:
        # Cancellation cuts both ways — both parties get notified; we can't tell who initiated at signal time
        for u in (instance.buyer, instance.listing.supplier):
            _notify(u, Notification.Kind.ORDER_CANCELLED,
                f"Order #{instance.pk} cancelled",
                f"Stock for {instance.listing.name_uz} has been restored.",
                f"/orders/{instance.pk}",
                extra={"order_id": instance.pk})
    else:
        # Forward transition (CONFIRMED/PROCESSING/IN_TRANSIT/DELIVERED) — buyer is the one tracking the order
        _notify(instance.buyer, Notification.Kind.ORDER_STATUS_CHANGED,
            f"Order #{instance.pk}: {instance.get_status_display()}",
            f"Your order for {instance.listing.name_uz} is now {instance.get_status_display().lower()}.",
            f"/orders/{instance.pk}",
            extra={"order_id": instance.pk, "status": instance.status})
