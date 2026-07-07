"""Django admin registration for CourierProfile + Delivery. Ops uses this to reassign stuck
deliveries + audit courier state."""
from django.contrib import admin

from .models import CourierProfile, Delivery


@admin.register(CourierProfile)
class CourierProfileAdmin(admin.ModelAdmin):
    list_display = ("user_email", "full_name", "vehicle_kind", "is_online",
                    "rating_avg", "rating_count", "lifetime_deliveries",
                    "lifetime_earnings_uzs", "created_at")
    list_filter = ("vehicle_kind", "is_online")
    search_fields = ("user__email", "user__phone", "full_name", "vehicle_plate")
    readonly_fields = ("created_at", "updated_at")

    @admin.display(description="email", ordering="user__email")
    def user_email(self, obj): return obj.user.email


@admin.register(Delivery)
class DeliveryAdmin(admin.ModelAdmin):
    list_display = ("id", "order_id", "courier_email", "status",
                    "payout_uzs", "cash_collected_uzs", "picked_up_at", "delivered_at",
                    "created_at")
    list_filter = ("status",)
    search_fields = ("order__id", "courier__email", "order__buyer__email")
    autocomplete_fields = ("courier",)
    readonly_fields = ("created_at", "updated_at")

    @admin.display(description="courier", ordering="courier__email")
    def courier_email(self, obj): return obj.courier.email
