from django.apps import AppConfig


class QassobsConfig(AppConfig):
    """v3.8 — Qassob (butcher + slaughterhouse / qushxona) profile + admin + listing surface.

    Decoupled from `apps.suppliers` because qassobs aren't sellers — they're service-hub operators that
    accept slaughter+cut jobs assigned from the buyer-side delivery flow. They have their own profile
    fields (years_experience, daily_capacity_head, animals_supported) and appear on the buyer app's
    "Servislar" tab. KYC verification gates their visibility same as SupplierProfile.is_verified gates
    listings."""
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.qassobs"
