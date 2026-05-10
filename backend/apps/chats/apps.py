"""Chats app — 1:1 conversations and messages. v2 is polling-based; websocket upgrade comes later."""
from django.apps import AppConfig


class ChatsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.chats"
