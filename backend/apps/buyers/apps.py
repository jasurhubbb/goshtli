"""Buyers app — owns BuyerProfile, buyer-only endpoints, and the auto-create-profile signal on user creation."""
from django.apps import AppConfig


class BuyersConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.buyers"

    def ready(self):
        # Side-effect import: registers the post_save handler that auto-creates BuyerProfile for BUYER users
        from . import signals  # noqa: F401
