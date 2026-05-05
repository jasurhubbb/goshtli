"""Orders app — owns Order model, the order state machine, and the atomic stock-mutation service used at create/cancel."""
from django.apps import AppConfig


class OrdersConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.orders"
