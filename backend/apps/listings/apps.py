"""Listings app — the catalog (Listing + MeatCategory + PriceHistory).

The ready() hook imports signals so the price-history logger is wired up at startup.
"""
from django.apps import AppConfig


class ListingsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.listings"

    def ready(self):
        # Importing for side effects — registers @receiver handlers on the pre_save / post_save signals.
        from . import signals  # noqa: F401
