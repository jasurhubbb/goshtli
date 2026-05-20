"""AppConfig for the markets app — the catalog's vendor layer.

A Market is the multi-tenant pivot: every Listing lives inside exactly one Market, so buyers can browse
"products by market" (Wolt/Uber Eats-style) or "products by category across all markets".
"""
from django.apps import AppConfig


class MarketsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.markets"
    verbose_name = "Markets"
