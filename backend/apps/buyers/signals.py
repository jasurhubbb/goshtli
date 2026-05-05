"""Auto-create BuyerProfile when a BUYER user is saved — mirrors the suppliers signal so /buyers/me is always populated."""
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import BuyerProfile


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def ensure_buyer_profile(sender, instance, created, **kwargs):
    # Skip non-buyers; get_or_create makes this safe to fire on every save
    if instance.role != "BUYER": return
    BuyerProfile.objects.get_or_create(user=instance)
