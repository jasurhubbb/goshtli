"""SupplierProfile is now opt-in (v2 unified user model) — created when the user explicitly "becomes a seller",
not automatically at registration. The legacy auto-create-on-role=SUPPLIER kept here for backwards compat with
existing data: any user that still has role=SUPPLIER continues to get their profile.

New users in v2 will have role=BUYER (the default), and choose to enable selling via a dedicated endpoint
(POST /api/v1/suppliers/me/ or via the Profile screen). Once they opt in, admin still has to set is_verified=True.
"""
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import SupplierProfile


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def ensure_supplier_profile(sender, instance, created, **kwargs):
    # Backwards-compat: anyone with role=SUPPLIER still gets a profile auto-created. New flow uses the opt-in endpoint.
    # v3.8.2: auto-verify on creation so new suppliers can list immediately — admin-gated KYC verification
    # is deferred until we have a real review queue. Re-enabling is a one-line change here + relaxing the
    # backfill migration; the IsVerifiedSupplier permission class is left intact for future re-enable.
    if instance.role != "SUPPLIER": return
    SupplierProfile.objects.get_or_create(user=instance,
        defaults={"business_name": "", "is_verified": True})
