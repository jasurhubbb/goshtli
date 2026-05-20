"""Order business logic — kept out of views per the README's service-layer rule. Stock mutations + state machine live here.

Every mutation runs inside transaction.atomic() with select_for_update() on the listing row, so concurrent
order placements can't oversell stock. Status transitions are validated against ALLOWED_TRANSITIONS — any
disallowed change raises InvalidStatusTransition, which views translate into a 400 response.
"""
from decimal import Decimal
from django.core.exceptions import ValidationError
from django.db import transaction

from apps.listings.models import Listing
from .models import Order


# ---------- Custom exceptions — views catch these and convert to API errors ----------

class InsufficientStock(ValidationError):
    """Order quantity exceeds the listing's available kg. Caller should retry with a lower quantity or a different listing."""


class ListingNotOrderable(ValidationError):
    """Listing is OUT_OF_STOCK or ARCHIVED — only ACTIVE listings accept new orders per workflow spec."""


class InvalidStatusTransition(ValidationError):
    """Requested status change is not allowed from the order's current state, or not allowed for this role."""


class CancellationNotAllowed(ValidationError):
    """Order is in a terminal or non-cancellable state for the requesting user (e.g. buyer trying to cancel CONFIRMED)."""


# ---------- State machine — single source of truth for who can change what ----------

# Per workflow.md §7: buyer can only cancel from PENDING; supplier drives the rest of the lifecycle.
SUPPLIER_TRANSITIONS = {
    Order.Status.PENDING: {Order.Status.CONFIRMED, Order.Status.CANCELLED},
    Order.Status.CONFIRMED: {Order.Status.PROCESSING, Order.Status.CANCELLED},
    Order.Status.PROCESSING: {Order.Status.IN_TRANSIT, Order.Status.CANCELLED},
    Order.Status.IN_TRANSIT: {Order.Status.DELIVERED},
    # DELIVERED + CANCELLED are terminal — no key here
}
BUYER_CANCELLABLE_FROM = {Order.Status.PENDING}  # buyer's only allowed transition is PENDING → CANCELLED


# ---------- Public service functions ----------

@transaction.atomic
def create_order(*, buyer, listing_id: int, quantity_kg: Decimal, delivery_address: str, notes: str = "") -> Order:
    """Place an order: lock the listing row, validate stock, decrement quantity, flip to OUT_OF_STOCK if zero, snapshot price."""
    # select_for_update locks the listing row until commit — concurrent buyers can't both succeed when only 1kg remains
    try: listing = Listing.objects.select_for_update().get(pk=listing_id)
    except Listing.DoesNotExist: raise ValidationError({"listing": "Listing does not exist."})

    if listing.status != Listing.Status.ACTIVE: raise ListingNotOrderable({"listing": f"Listing is {listing.status}, not ACTIVE."})
    if quantity_kg <= 0: raise ValidationError({"quantity_kg": "Must be greater than zero."})
    if quantity_kg > listing.quantity_kg:
        raise InsufficientStock({"quantity_kg": f"Only {listing.quantity_kg}kg available."})

    # Snapshot total_price NOW so future price changes on the listing never affect this order's amount
    total_price = (listing.price_per_kg * quantity_kg).quantize(Decimal("0.01"))
    order = Order.objects.create(buyer=buyer, listing=listing, quantity_kg=quantity_kg,
                                 total_price=total_price, delivery_address=delivery_address, notes=notes)

    # Decrement stock and auto-flip to OUT_OF_STOCK when fully drained — single save() to keep DB writes minimal
    listing.quantity_kg -= quantity_kg
    if listing.quantity_kg <= 0: listing.status = Listing.Status.OUT_OF_STOCK
    listing.save(update_fields=("quantity_kg", "status", "updated_at"))
    return order


@transaction.atomic
def cancel_order(*, order_id: int, by_user) -> Order:
    """Cancel an order and restore listing stock — re-activates listing if it was OUT_OF_STOCK and is now back above zero."""
    # Lock both the order and its listing so a concurrent status update can't race the cancellation
    order = Order.objects.select_for_update().select_related("listing").get(pk=order_id)
    listing = Listing.objects.select_for_update().get(pk=order.listing_id)

    # Authorization + state check — buyer can only cancel own PENDING; supplier can cancel anything still cancellable on their listing
    is_buyer = (order.buyer_id == by_user.id)
    is_supplier = (listing.supplier_id == by_user.id)
    if not (is_buyer or is_supplier): raise CancellationNotAllowed("You don't own this order.")
    if order.is_terminal: raise CancellationNotAllowed(f"Order is already {order.status}.")
    if is_buyer and not is_supplier and order.status not in BUYER_CANCELLABLE_FROM:
        raise CancellationNotAllowed("Buyers can only cancel PENDING orders.")
    if is_supplier and order.status not in SUPPLIER_TRANSITIONS or \
       (is_supplier and Order.Status.CANCELLED not in SUPPLIER_TRANSITIONS.get(order.status, set())):
        # Supplier can cancel from PENDING/CONFIRMED/PROCESSING but not from IN_TRANSIT (already shipped)
        if not is_buyer: raise CancellationNotAllowed(f"Cannot cancel from status {order.status}.")

    order.status = Order.Status.CANCELLED
    order.save(update_fields=("status", "updated_at"))

    # Restore stock — and bring the listing back to ACTIVE if it was OUT_OF_STOCK but now has stock again
    listing.quantity_kg += order.quantity_kg
    if listing.status == Listing.Status.OUT_OF_STOCK and listing.quantity_kg > 0:
        listing.status = Listing.Status.ACTIVE
    listing.save(update_fields=("quantity_kg", "status", "updated_at"))
    return order


@transaction.atomic
def transition_order_status(*, order_id: int, new_status: str, by_user) -> Order:
    """Supplier-driven state transitions (CONFIRMED, PROCESSING, IN_TRANSIT, DELIVERED). CANCELLED routes through cancel_order to restore stock."""
    if new_status == Order.Status.CANCELLED:
        return cancel_order(order_id=order_id, by_user=by_user)  # delegate so stock-restore logic isn't duplicated

    order = Order.objects.select_for_update().select_related("listing").get(pk=order_id)
    if order.listing.supplier_id != by_user.id:
        raise InvalidStatusTransition("Only the listing's supplier can transition this order.")
    allowed = SUPPLIER_TRANSITIONS.get(order.status, set())
    if new_status not in allowed:
        raise InvalidStatusTransition(f"Cannot move from {order.status} to {new_status}. Allowed: {sorted(allowed) or 'none (terminal)'}")
    order.status = new_status
    order.save(update_fields=("status", "updated_at"))
    return order
