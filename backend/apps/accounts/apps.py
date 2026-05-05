"""Accounts app — owns the custom user model, registration, JWT login flow, and the /users/me endpoint."""
from django.apps import AppConfig


class AccountsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.accounts"
