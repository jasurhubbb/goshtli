"""Auto-assignment signal — when an Order transitions to IN_TRANSIT, create the corresponding
Delivery row (courier-side dispatch) and pick a courier.

Selection strategy (deterministic first-cut):

  1. If `order.listing.supplier_delivers=True` → assign the supplier themselves. The supplier gets
     an implicit CourierProfile via get_or_create so the delivery-side UI works for them without
     any role change.
  2. Otherwise → round-robin pick from ONLINE COURIER accounts, preferring the one with the
     fewest ACTIVE deliveries (load-balancing). Vehicle-type match against Order.delivery_vehicle_type
     if present.
  3. No eligible couriers → leave the Delivery row unassigned (courier=None) and log a warning;
     ops sees this in Django Admin.

This runs on every Order save so it's guarded by `_previous_status` (set by the pre_save signal in
apps.notifications.signals). Only the specific IN_TRANSIT transition triggers a Delivery insert.
"""
import logging

from django.contrib.auth import get_user_model
from django.db.models import Count, Q
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.orders.models import Order
from .models import CourierProfile, Delivery


log = logging.getLogger(__name__)


@receiver(post_save, sender=Order)
def _auto_assign_delivery(sender, instance, created, **kwargs):
    # Only fire on the IN_TRANSIT transition (the moment the supplier says "dispatched").
    if created: return
    prev = getattr(instance, "_previous_status", None)
    if prev == instance.status: return
    if instance.status != Order.Status.IN_TRANSIT: return

    # Idempotent — get_or_create means re-firing the signal won't create dupes even if
    # the state machine is retriggered.
    if hasattr(instance, "delivery"):
        return

    courier = _pick_courier(instance)
    Delivery.objects.create(order=instance,
                             courier=courier if courier is not None else _fallback_stub_user())
    if courier is None:
        log.warning("No eligible courier for order #%d; assigned fallback stub.", instance.pk)


def _pick_courier(order: Order):
    """Return the User to assign, or None if the platform has no eligible couriers."""
    User = get_user_model()

    # 1. supplier_delivers shortcut — bypass the pool entirely.
    listing = order.listing
    if getattr(listing, "supplier_delivers", False):
        _ensure_supplier_courier_profile(listing.supplier)
        return listing.supplier

    # 2. Round-robin over ONLINE couriers, load-balanced by active-delivery count.
    online_couriers = User.objects.filter(
        role=User.Role.COURIER,
        courier_profile__is_online=True,
    )

    # Optional vehicle match — many orders leave delivery_vehicle_type blank; when set, prefer
    # couriers whose vehicle matches. Fallback to any online courier when nothing matches.
    vehicle_pref = getattr(order, "delivery_vehicle_type", "") or ""
    if vehicle_pref:
        matched = online_couriers.filter(courier_profile__vehicle_kind=vehicle_pref)
        pool = matched if matched.exists() else online_couriers
    else:
        pool = online_couriers

    if not pool.exists(): return None

    # Load-balance — assign to the courier with the FEWEST in-progress deliveries.
    ACTIVE = (Delivery.Status.ASSIGNED, Delivery.Status.PICKED_UP,
              Delivery.Status.EN_ROUTE, Delivery.Status.ARRIVED)
    pool = pool.annotate(
        active_count=Count("deliveries",
                            filter=Q(deliveries__status__in=ACTIVE))
    ).order_by("active_count", "id")                                             # id tiebreaker for determinism
    return pool.first()


def _ensure_supplier_courier_profile(user):
    """Suppliers who mark supplier_delivers=True get an "implicit courier hat" — a CourierProfile
    with no role change. Idempotent."""
    CourierProfile.objects.get_or_create(
        user=user, defaults={"full_name": user.full_name or ""})


def _fallback_stub_user():
    """When no online courier exists we still need SOMETHING on the FK. Use the first admin as the
    stub — ops can reassign from Django Admin. Not great UX but avoids losing the Delivery row.
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()
    admin = User.objects.filter(role=User.Role.ADMIN).first()
    if admin is not None: return admin
    return User.objects.filter(is_superuser=True).first() or User.objects.first()
