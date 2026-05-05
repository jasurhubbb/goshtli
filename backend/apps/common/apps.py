"""Common app — holds shared base models, mixins, helpers, permissions, and pagination used across domain apps."""
from django.apps import AppConfig


class CommonConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.common"
