"""Request/response serializers for the Telegram phone-verification endpoints."""
from rest_framework import serializers


class TelegramStartSerializer(serializers.Serializer):
    """POST /auth/telegram/start/ — the app hands us the phone the user typed. We normalize + validate it in
    the view (normalize_uz_phone), so here we only require a non-empty string."""
    phone = serializers.CharField(max_length=32)


class TelegramVerifySerializer(serializers.Serializer):
    """POST /auth/telegram/verify/ — the code the user copied from the bot, tied to their start-session."""
    session_token = serializers.CharField(max_length=64)
    code = serializers.CharField(max_length=6, min_length=6)
