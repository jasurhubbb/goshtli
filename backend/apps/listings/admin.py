"""Django Admin for the catalog — Listing (the product), ListingPhoto (inline), and MeatCategory (the facet).

Permission model mirrors the Catalog Editor / Catalog Publisher Django Groups + is_superuser:
  • Editors can add + change non-destructive fields.
  • Publishers can additionally flip status (ACTIVE / OUT_OF_STOCK / ARCHIVED).
  • Hard delete is superuser-only; everyone else uses status=ARCHIVED for soft removal.
"""
from django.contrib import admin

from .models import Listing, MeatCategory, PriceHistory


@admin.register(MeatCategory)
class MeatCategoryAdmin(admin.ModelAdmin):
    """Catalog facet admin — workers add/edit/retire categories without a code deploy.

    Slug is prepopulated from name_uz; image is uploaded directly. Hard delete reserved for superuser since
    deleting a category would orphan listings that point at it (FK is PROTECT in the model)."""

    list_display = ("display_order", "name_uz", "name_ru", "slug", "is_active", "updated_at")
    list_display_links = ("name_uz",)
    list_editable = ("display_order", "is_active")  # quick toggling from the list page
    list_filter = ("is_active",)
    search_fields = ("name_uz", "name_ru", "slug")
    prepopulated_fields = {"slug": ("name_uz",)}
    readonly_fields = ("created_at", "updated_at")

    fieldsets = (
        (None, {"fields": ("slug", ("name_uz", "name_ru"))}),
        ("Visual", {"fields": ("image",)}),
        ("Ordering + status", {"fields": ("display_order", "is_active")}),
        ("Audit", {"fields": ("created_at", "updated_at"), "classes": ("collapse",)}),
    )

    def has_delete_permission(self, request, obj=None):
        """Soft-delete only (is_active=False) — hard delete is superuser-only to protect FK integrity."""
        return request.user.is_superuser


@admin.register(Listing)
class ListingAdmin(admin.ModelAdmin):
    """Product admin (model still named Listing internally for FK compatibility — verbose_name='product').

    Workflow:
      • Editors create / edit products; slug auto-populated from name_uz.
      • Publishers can flip status (ACTIVE / OUT_OF_STOCK / ARCHIVED). Editors cannot — see get_readonly_fields.
      • Soft-archive via status=ARCHIVED; hard delete is superuser-only.
      • supplier defaults to the request user on create; updated_by stamped on every save.

    List filtering uses the new schema (market, category, status) so workers can scope big catalogs quickly.
    """

    # ---- List view ----
    list_display = ("name_uz_or_title", "market_name", "category_name", "quantity_kg", "price_per_kg",
                    "status", "updated_at")
    list_display_links = ("name_uz_or_title",)
    list_filter = ("status", "category", "market", "market__region")
    search_fields = ("name_uz", "name_ru", "slug", "supplier__email", "market__name_uz", "market__name_ru")
    list_select_related = ("supplier", "market", "category")
    autocomplete_fields = ("supplier",)
    date_hierarchy = "available_from"
    list_per_page = 50

    # ---- Detail view ----
    prepopulated_fields = {"slug": ("name_uz",)}
    readonly_fields = ("created_at", "updated_at", "created_by", "updated_by")
    fieldsets = (
        (None, {"fields": ("market", "category", "slug")}),
        ("Names + description", {"fields": (("name_uz", "name_ru"), ("description_uz", "description_ru"))}),
        ("Commerce", {"fields": (("quantity_kg", "price_per_kg"), ("status", "available_from"), "location")}),
        ("Ownership", {"fields": ("supplier",)}),
        ("Audit", {"fields": ("created_by", "updated_by", "created_at", "updated_at"), "classes": ("collapse",)}),
    )

    # ---- Permission overrides ----
    def get_readonly_fields(self, request, obj=None):
        """Catalog Editor cannot change status (only Publisher / Superuser can flip ACTIVE → ARCHIVED)."""
        ro = list(super().get_readonly_fields(request, obj))
        if not request.user.is_superuser and not request.user.groups.filter(name="Catalog Publisher").exists():
            ro.append("status")
        return ro

    def has_delete_permission(self, request, obj=None):
        """Hard delete reserved for superuser — Admin uses status=ARCHIVED for soft delete."""
        return request.user.is_superuser

    def save_model(self, request, obj, form, change):
        """Stamp created_by on first save, updated_by always. supplier defaults to the current user if unset.
        Setting _actor lets the price-history signal credit this user on price changes."""
        if not obj.pk:
            obj.created_by = request.user
            if not obj.supplier_id: obj.supplier = request.user
        obj.updated_by = request.user
        obj._actor = request.user  # consumed by apps.listings.signals._log_price_change
        super().save_model(request, obj, form, change)

    # ---- Custom list-display callables ----
    @admin.display(description="name", ordering="name_uz")
    def name_uz_or_title(self, obj): return obj.name_uz or f"Product #{obj.pk}"

    @admin.display(description="market", ordering="market__name_uz")
    def market_name(self, obj): return obj.market.name_uz if obj.market_id else "—"

    @admin.display(description="category", ordering="category__name_uz")
    def category_name(self, obj): return obj.category.name_uz if obj.category_id else "—"


@admin.register(PriceHistory)
class PriceHistoryAdmin(admin.ModelAdmin):
    """Read-only ledger of price changes. Created by the post_save signal on Listing; never written by hand.

    Useful when a buyer disputes a price ("it said 80,000 yesterday!") or when ops investigates whether a
    worker accidentally moved a decimal place."""

    list_display = ("listing", "old_price", "new_price", "delta_pct", "changed_by", "created_at")
    list_filter = ("changed_by", "listing__market", "listing__category")
    search_fields = ("listing__name_uz", "listing__name_ru", "listing__slug", "changed_by__email")
    list_select_related = ("listing", "listing__market", "listing__category", "changed_by")
    readonly_fields = ("listing", "old_price", "new_price", "changed_by", "created_at", "updated_at")
    date_hierarchy = "created_at"
    list_per_page = 100

    def has_add_permission(self, request): return False     # only the signal creates these
    def has_change_permission(self, request, obj=None): return False
    def has_delete_permission(self, request, obj=None): return request.user.is_superuser

    @admin.display(description="Δ %")
    def delta_pct(self, obj):
        """Percentage change from old → new. Negative = price drop. Format with sign + one decimal place."""
        if obj.old_price == 0: return "—"
        pct = ((obj.new_price - obj.old_price) / obj.old_price) * 100
        return f"{pct:+.1f}%"
