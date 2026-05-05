"""Auto-create SupplierProfile whenever a user is saved with role=SUPPLIER and no profile yet — keeps /me endpoints from 404ing."""
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import SupplierProfile


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def ensure_supplier_profile(sender, instance, created, **kwargs):
    # Idempotent — fires on every save but get_or_create only inserts once. Skips ADMIN/BUYER users entirely.
    if instance.role != "SUPPLIER": return
    SupplierProfile.objects.get_or_create(user=instance, defaults={"business_name": ""})
