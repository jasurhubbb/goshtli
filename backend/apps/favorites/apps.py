"""Favorites app — lightweight pivot between users and listings they've saved (the heart icon)."""
from django.apps import AppConfig


class FavoritesConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.favorites"
