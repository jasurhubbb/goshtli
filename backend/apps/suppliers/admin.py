"""Django Admin for SupplierProfile — gives admins the verification toggle UI required by the workflow spec."""
from django.contrib import admin
from .models import SupplierProfile


@admin.register(SupplierProfile)
class SupplierProfileAdmin(admin.ModelAdmin):
    # Most-used columns first — verification status is the column admins actually scan for
    list_display = ("business_name", "user_email", "region", "is_verified", "created_at")
    list_filter = ("is_verified", "region")
    search_fields = ("business_name", "user__email", "user__full_name", "region")
    list_select_related = ("user",)            # avoids N+1 when rendering user_email column
    autocomplete_fields = ("user",)            # smarter user picker for big datasets
    readonly_fields = ("created_at", "updated_at")
    actions = ("verify_selected", "unverify_selected")

    @admin.display(description="email", ordering="user__email")
    def user_email(self, obj): return obj.user.email

    @admin.action(description="Mark selected suppliers as VERIFIED")
    def verify_selected(self, request, queryset): queryset.update(is_verified=True)

    @admin.action(description="Mark selected suppliers as UNVERIFIED")
    def unverify_selected(self, request, queryset): queryset.update(is_verified=False)
