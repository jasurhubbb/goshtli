from django.apps import AppConfig


class PartnerConfig(AppConfig):
    """v3.8 — cross-role partner-app endpoints. Houses views that the partner-app uses regardless of
    whether the caller is a SUPPLIER or QASSOB: order inbox, accept/reject/advance, earnings, dashboard
    KPIs, capacity calendar, ratings inbox, loyalty insights, smart tips. Each endpoint internally
    routes data + queries by role so the mobile app only learns ONE URL set."""
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.partner"
