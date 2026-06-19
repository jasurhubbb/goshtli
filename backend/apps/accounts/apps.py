"""Accounts app — owns the custom user model, registration, JWT login flow, and the /users/me endpoint."""
from django.apps import AppConfig


class AccountsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.accounts"

    def ready(self):
        # v3.8 — wire the KYC verification signal. Importing the kyc module registers the
        # auto_verify_on_full_kyc_approval receiver on post_save of KYCDocument.
        from . import kyc  # noqa: F401
