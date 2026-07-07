from django.apps import AppConfig


class CouriersConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.couriers"
    verbose_name = "Couriers"

    def ready(self):
        # Wire the auto-assignment signal on Order.post_save (see signals.py). Runs after every
        # order state change; guarded to only act on the IN_TRANSIT transition.
        from . import signals  # noqa: F401
