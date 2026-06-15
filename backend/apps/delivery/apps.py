from django.apps import AppConfig


class DeliveryConfig(AppConfig):
    """Delivery / fleet / pricing endpoints. Pure compute (no models) for v1 — quotes are computed on
    every request from the active rate-card constants in `pricing.py`. Persistence happens on the Order
    model itself (delivery_* fields)."""
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.delivery"
