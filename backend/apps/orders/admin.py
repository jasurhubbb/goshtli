"""Django Admin for Order — primary ops surface for spotting stuck or disputed orders."""
from django.contrib import admin
from .models import Order


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ("id", "buyer_email", "listing_title", "quantity_kg", "total_price", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("buyer__email", "listing__title", "delivery_address")
    list_select_related = ("buyer", "listing")
    autocomplete_fields = ("buyer", "listing")
    readonly_fields = ("total_price", "created_at", "updated_at")  # never let admin edit price directly — service layer owns it
    date_hierarchy = "created_at"

    @admin.display(description="buyer", ordering="buyer__email")
    def buyer_email(self, obj): return obj.buyer.email

    @admin.display(description="listing", ordering="listing__title")
    def listing_title(self, obj): return obj.listing.title
