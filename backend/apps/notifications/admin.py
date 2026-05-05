"""Django Admin for Notification — primarily for ops debugging; users themselves use the in-app bell list."""
from django.contrib import admin
from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("title", "user_email", "kind", "is_read", "created_at")
    list_filter = ("kind", "is_read")
    search_fields = ("title", "message", "user__email")
    list_select_related = ("user",)
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")

    @admin.display(description="user", ordering="user__email")
    def user_email(self, obj): return obj.user.email
