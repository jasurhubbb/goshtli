"""Django Admin for Order — primary ops surface for spotting stuck or disputed orders.

v3.6 / PRD-v2: includes bulk-action buttons for every supplier-side status transition. Editing the
status field directly on the change form BYPASSES the service-layer guards (stock restore on cancel,
allowed-transition checks), so don't use the dropdown for state moves — use the actions in the list
view instead. They route through `services.transition_order_status()` and respect the state machine.

For the buyer: the buyer's "Buyurtmani bekor qilish" button in the mobile app goes through the same
service layer, so a buyer-cancel and an admin-cancel-via-action restore stock identically.
"""
from django.contrib import admin, messages
from django.utils.translation import ngettext

from .models import Order
from .services import (CancellationNotAllowed, InvalidStatusTransition,
                       cancel_order, transition_order_status)


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ("id", "buyer_email", "listing_name", "quantity_kg", "total_price",
                    "status", "payment_status", "created_at")
    list_filter = ("status", "payment_status")
    search_fields = ("buyer__email", "listing__name_uz", "listing__name_ru", "delivery_address")
    list_select_related = ("buyer", "listing")
    autocomplete_fields = ("buyer", "listing")
    readonly_fields = ("total_price", "created_at", "updated_at")  # never let admin edit price directly — service layer owns it
    date_hierarchy = "created_at"

    # v3.6 — supplier-side transitions exposed as bulk actions. Pick orders in the list view, choose an
    # action from the dropdown, hit Go. Each action runs the SAME service-layer code path the
    # /orders/supplier/<id>/status/ endpoint uses, so admin actions and live API moves stay in sync.
    actions = ("mark_confirmed", "mark_processing", "mark_in_transit",
               "mark_delivered", "cancel_with_stock_restore")

    @admin.display(description="buyer", ordering="buyer__email")
    def buyer_email(self, obj): return obj.buyer.email

    @admin.display(description="listing", ordering="listing__name_uz")
    def listing_name(self, obj): return obj.listing.name_uz

    # ---------------- Bulk actions ----------------

    def _bulk_transition(self, request, queryset, target, action_label: str):
        """Shared loop — apply transition_order_status() to every selected row. Aggregates ok/skip
        counts into one admin message so a 50-row bulk move shows as "12 moved, 3 skipped (already
        DELIVERED), 0 errored" instead of 50 individual flashes."""
        ok, skipped = 0, []
        for order in queryset:
            try:
                # by_user is set to the listing's supplier so the permission check inside the service
                # layer passes — admins don't have their own "supplier" identity, so we proxy through.
                transition_order_status(order_id=order.id, new_status=target,
                                        by_user=order.listing.supplier)
                ok += 1
            except InvalidStatusTransition as e:
                skipped.append(f"#{order.id}: {e}")
            except Exception as e:                           # broad on purpose — admin shouldn't 500 on partial failure
                skipped.append(f"#{order.id}: {e}")
        if ok:
            self.message_user(request, ngettext(
                "%(n)d order moved to %(s)s.", "%(n)d orders moved to %(s)s.", ok)
                % {"n": ok, "s": target}, level=messages.SUCCESS)
        if skipped:
            self.message_user(request, "Skipped: " + "; ".join(skipped), level=messages.WARNING)

    @admin.action(description="Mark CONFIRMED (supplier accepts)")
    def mark_confirmed(self, request, queryset):
        self._bulk_transition(request, queryset, Order.Status.CONFIRMED, "CONFIRMED")

    @admin.action(description="Mark PROCESSING (preparing the goods)")
    def mark_processing(self, request, queryset):
        self._bulk_transition(request, queryset, Order.Status.PROCESSING, "PROCESSING")

    @admin.action(description="Mark IN_TRANSIT (driver on the way)")
    def mark_in_transit(self, request, queryset):
        self._bulk_transition(request, queryset, Order.Status.IN_TRANSIT, "IN_TRANSIT")

    @admin.action(description="Mark DELIVERED (order completed)")
    def mark_delivered(self, request, queryset):
        self._bulk_transition(request, queryset, Order.Status.DELIVERED, "DELIVERED")

    @admin.action(description="Cancel order (restores stock atomically)")
    def cancel_with_stock_restore(self, request, queryset):
        ok, skipped = 0, []
        for order in queryset:
            try:
                # Route through cancel_order — it restores stock AND flips listing back to ACTIVE if
                # it was OUT_OF_STOCK and is now stocked again. We pass the supplier as by_user so the
                # role check inside the service treats this as a supplier-side cancellation.
                cancel_order(order_id=order.id, by_user=order.listing.supplier)
                ok += 1
            except CancellationNotAllowed as e:
                skipped.append(f"#{order.id}: {e}")
            except Exception as e:
                skipped.append(f"#{order.id}: {e}")
        if ok:
            self.message_user(request,
                ngettext("%d order cancelled (stock restored).",
                         "%d orders cancelled (stock restored).", ok) % ok,
                level=messages.SUCCESS)
        if skipped:
            self.message_user(request, "Skipped: " + "; ".join(skipped), level=messages.WARNING)
