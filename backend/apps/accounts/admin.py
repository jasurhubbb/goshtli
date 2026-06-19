"""Django Admin registration for User — gives admins a UI to view, search, filter, and toggle is_active per spec."""
from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.utils.html import format_html
from .models import KYCDocument, User


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


@admin.register(KYCDocument)
class KYCDocumentAdmin(admin.ModelAdmin):
    """KYC review surface — admins approve passports / business licenses uploaded by partners. Once
    PASSPORT + BUSINESS_LICENSE are both approved for a user, the signal in apps.accounts.kyc flips
    their profile.is_verified=True and pushes an FCM message to the partner-app."""

    list_display = ("user_email", "kind", "is_approved_badge", "image_preview", "created_at")
    list_display_links = ("user_email",)
    list_filter = ("kind", "is_approved", "created_at")
    search_fields = ("user__email", "user__full_name", "user__phone")
    list_select_related = ("user",)
    readonly_fields = ("created_at", "updated_at", "image_preview")
    autocomplete_fields = ("user",)
    actions = ("mark_approved", "mark_rejected")

    fieldsets = (
        (None, {"fields": ("user", "kind", "image", "image_preview")}),
        ("Review", {"fields": ("is_approved", "admin_notes")}),
        ("Audit", {"fields": ("created_at", "updated_at"), "classes": ("collapse",)}),
    )

    @admin.display(description="user", ordering="user__email")
    def user_email(self, obj): return obj.user.email

    @admin.display(description="status")
    def is_approved_badge(self, obj):
        if obj.is_approved:
            return format_html('<span style="color:#1f5e1f;font-weight:700">✓ APPROVED</span>')
        return format_html('<span style="color:#8a4f00;font-weight:700">⏳ PENDING</span>')

    @admin.display(description="preview")
    def image_preview(self, obj):
        if not obj.image: return "—"
        return format_html('<img src="{}" style="max-height:160px;max-width:240px;border-radius:6px;" />',
                            obj.image.url)

    @admin.action(description="Approve selected KYC documents (may auto-verify partner)")
    def mark_approved(self, request, queryset):
        # Iterate (not .update()) so the post_save signal fires for the auto-verify flow.
        n = 0
        for doc in queryset:
            if not doc.is_approved:
                doc.is_approved = True
                doc.save(update_fields=["is_approved", "updated_at"])
                n += 1
        self.message_user(request, f"{n} KYC document(s) approved.", level=messages.SUCCESS)

    @admin.action(description="Mark NOT APPROVED (partner needs to re-upload)")
    def mark_rejected(self, request, queryset):
        n = queryset.update(is_approved=False)
        self.message_user(request, f"{n} KYC document(s) marked not approved.", level=messages.WARNING)
