"""Read-mostly admin for verification rows — lets ops eyeball stuck sessions + confirm delivery. The code
digest is never shown (there's no plaintext to show) and rows are auto-swept, so this is diagnostic only."""
from django.contrib import admin

from .models import TelegramVerification


@admin.register(TelegramVerification)
class TelegramVerificationAdmin(admin.ModelAdmin):
    list_display = ("phone", "status", "attempts", "code_sent_at", "code_expires_at",
                    "consumed_at", "created_at")
    list_filter = ("status",)
    search_fields = ("phone", "session_token", "telegram_user_id")
    readonly_fields = ("phone", "session_token", "status", "code_hash", "attempts", "code_sent_at",
                       "code_expires_at", "consumed_at", "telegram_user_id", "telegram_chat_id",
                       "created_at", "updated_at")
