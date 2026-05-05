"""Django Admin registration for User — gives admins a UI to view, search, filter, and toggle is_active per spec."""
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    """Adapts Django's built-in UserAdmin to our email-based custom user — preserves password hashing & permissions UI."""
    ordering = ("-created_at",)
    list_display = ("email", "full_name", "role", "is_active", "is_staff", "created_at")
    list_filter = ("role", "is_active", "is_staff", "is_superuser")
    search_fields = ("email", "full_name", "phone")
    readonly_fields = ("created_at", "updated_at", "last_login")

    # Edit form layout — grouped by concern: identity, role, permissions, audit timestamps
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("full_name", "phone", "role")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Audit", {"fields": ("last_login", "created_at", "updated_at")}),
    )
    # Add-form layout — minimal fields needed at creation; rest can be filled in afterward
    add_fieldsets = (
        (None, {"classes": ("wide",),
                "fields": ("email", "full_name", "phone", "role", "password1", "password2", "is_staff", "is_superuser")}),
    )
