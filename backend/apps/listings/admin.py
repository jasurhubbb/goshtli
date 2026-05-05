"""Django Admin for Listing — supports filtering by status/meat_type/region for ops monitoring."""
from django.contrib import admin
from .models import Listing


@admin.register(Listing)
class ListingAdmin(admin.ModelAdmin):
    list_display = ("title", "supplier_email", "meat_type", "quantity_kg", "price_per_kg", "status", "created_at")
    list_filter = ("status", "meat_type")
    search_fields = ("title", "supplier__email", "location", "description")
    list_select_related = ("supplier",)
    autocomplete_fields = ("supplier",)
    readonly_fields = ("created_at", "updated_at")
    date_hierarchy = "available_from"

    @admin.display(description="supplier", ordering="supplier__email")
    def supplier_email(self, obj): return obj.supplier.email
