"""Admin for Market — the worker-facing CRUD surface for vendor onboarding.

Permission rules baked in here (mirror the Catalog Publisher / Editor / Viewer Django Groups):
  • Anyone in the staff (is_staff=True) can list + view markets.
  • Catalog Editor — can add + edit non-destructive fields (name, hours, photos, address, etc.).
  • Catalog Publisher / Superuser — can flip is_active (soft-archive a market) and assign created_by.
  • Hard delete is reserved for is_superuser. Admins should soft-archive via is_active=False.
"""
from django.contrib import admin

from .models import Market


@admin.register(Market)
class MarketAdmin(admin.ModelAdmin):
    """Inline workflow: workers see all key fields on one page, with sensible sectioning + a slug field that's
    auto-populated from name_uz so they never need to type one manually."""

    # List view — gives workers a glanceable overview with the controls they actually use
    list_display = ("name_uz", "region", "phone", "is_active", "updated_at")
    list_filter = ("region", "is_active")
    search_fields = ("name_uz", "name_ru", "slug", "address", "phone")
    list_select_related = ()  # no FKs on the list — adjust when we add owner/manager FK
    list_per_page = 50

    # Slug is auto-populated from name_uz; admin can still override before save
    prepopulated_fields = {"slug": ("name_uz",)}
    readonly_fields = ("created_at", "updated_at", "created_by", "updated_by")

    # Fieldsets group related fields — quicker scan than a flat form, especially with bilingual content
    fieldsets = (
        (None, {"fields": ("slug", ("name_uz", "name_ru"))}),
        ("Brand", {"fields": ("logo", "cover", ("description_uz", "description_ru"))}),
        ("Location", {"fields": ("region", "address", ("lat", "lng"))}),
        ("Contact + hours", {"fields": ("phone", "working_hours"),
                              "description": "working_hours format: {\"mon\": [9, 21], \"sun\": null} — null=closed"}),
        ("Lifecycle", {"fields": ("is_active",),
                       "description": "Uncheck to hide from buyers; row stays in DB for order history."}),
        ("Audit", {"fields": ("created_by", "updated_by", "created_at", "updated_at"),
                   "classes": ("collapse",)}),
    )

    # ---- Permission overrides — the heart of the RBAC story ------------------
    # By default any staff with Market change permission could flip is_active, which is the soft-archive button.
    # We restrict that to publishers + superusers via get_readonly_fields().

    def get_readonly_fields(self, request, obj=None):
        """Catalog Editor sees is_active as readonly; only Publisher/Superuser can soft-archive a market."""
        ro = list(super().get_readonly_fields(request, obj))
        if not request.user.is_superuser and not request.user.groups.filter(name="Catalog Publisher").exists():
            ro.append("is_active")
        return ro

    def has_delete_permission(self, request, obj=None):
        """Hard delete is superuser-only — Admins use is_active=False (soft archive) instead.
        Prevents accidental loss of historical order/review references that FK back to this row."""
        return request.user.is_superuser

    # ---- Stamp who created / updated each row --------------------------------
    def save_model(self, request, obj, form, change):
        """Populate created_by on first save, updated_by on every save. We do this in admin (not model.save)
        because the User is only knowable inside a request context."""
        if not obj.pk:
            obj.created_by = request.user
        obj.updated_by = request.user
        super().save_model(request, obj, form, change)
