"""Django admin for QassobProfile. Workers verify qassobs from the list view after KYC docs land in
apps.accounts admin. Bulk action 'Verify' flips is_verified=True for selected rows; a post-save signal
in apps.qassobs.signals fires an FCM push so the partner sees the green banner on next app open."""
from django.contrib import admin, messages

from .models import QassobProfile


@admin.register(QassobProfile)
class QassobProfileAdmin(admin.ModelAdmin):
    list_display = ("full_name", "user_email", "region", "is_slaughterhouse", "is_verified",
                    "is_open_now", "rating_avg", "rating_count", "created_at")
    list_display_links = ("full_name",)
    list_filter = ("is_verified", "is_slaughterhouse", "is_open_now", "region")
    search_fields = ("full_name", "user__email", "user__phone", "region", "address")
    list_select_related = ("user",)
    readonly_fields = ("created_at", "updated_at", "rating_avg", "rating_count")
    autocomplete_fields = ("user",)
    actions = ("mark_verified", "mark_unverified")

    fieldsets = (
        ("Identity", {"fields": ("user", "full_name", "years_experience")}),
        ("Location", {"fields": ("region", "address", ("lat", "lng"), "service_radius_km")}),
        ("Service", {"fields": ("animals_supported", "is_slaughterhouse", "daily_capacity_head",
                                 "photo", "phone_visible", "telegram_username")}),
        ("Status", {"fields": ("is_verified", "is_open_now")}),
        ("Ratings (denormalised)", {"fields": ("rating_avg", "rating_count"), "classes": ("collapse",)}),
        ("Audit", {"fields": ("created_at", "updated_at"), "classes": ("collapse",)}),
    )

    @admin.display(description="email", ordering="user__email")
    def user_email(self, obj): return obj.user.email

    @admin.action(description="Mark VERIFIED (allow appearing in buyer Servislar tab)")
    def mark_verified(self, request, queryset):
        n = queryset.update(is_verified=True)
        self.message_user(request, f"{n} qassob(s) marked verified.", level=messages.SUCCESS)

    @admin.action(description="Mark NOT VERIFIED (hide from buyer Servislar tab)")
    def mark_unverified(self, request, queryset):
        n = queryset.update(is_verified=False)
        self.message_user(request, f"{n} qassob(s) marked NOT verified.", level=messages.WARNING)
