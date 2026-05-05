"""Suppliers app — owns SupplierProfile, supplier-only endpoints, and the auto-create-profile signal on user creation."""
from django.apps import AppConfig


class SuppliersConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.suppliers"

    def ready(self):
        # Import side-effect: registers the post_save signal handler that auto-creates SupplierProfile
        from . import signals  # noqa: F401
