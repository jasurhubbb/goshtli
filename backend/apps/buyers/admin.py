"""Django Admin for BuyerProfile — read-mostly UI; admin rarely edits buyers but needs to inspect them."""
from django.contrib import admin
from .models import BuyerProfile


@admin.register(BuyerProfile)
class BuyerProfileAdmin(admin.ModelAdmin):
    list_display = ("business_name", "user_email", "region", "created_at")
    list_filter = ("region",)
    search_fields = ("business_name", "user__email", "user__full_name", "region")
    list_select_related = ("user",)
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")

    @admin.display(description="email", ordering="user__email")
    def user_email(self, obj): return obj.user.email
