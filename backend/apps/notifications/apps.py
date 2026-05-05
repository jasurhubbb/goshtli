"""Notifications app — owns the Notification model + post_save signals that auto-create entries on supplier verification + order events."""
from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.notifications"

    def ready(self):
        # Side-effect import: registers all the auto-create handlers across orders + suppliers
        from . import signals  # noqa: F401
