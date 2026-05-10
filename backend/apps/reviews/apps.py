"""Reviews app — 1-5 star ratings + optional comment, one per delivered order."""
from django.apps import AppConfig


class ReviewsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.reviews"
