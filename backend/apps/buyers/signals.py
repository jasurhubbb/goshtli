"""Auto-create BuyerProfile for every new user (unified user model: anyone can buy).

Previously gated on role=BUYER; in v2 every account is a potential buyer, so we always provision the profile.
ADMIN users get one too — harmless, and means superusers can use buyer-facing endpoints if they want.
"""
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import BuyerProfile


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def ensure_buyer_profile(sender, instance, created, **kwargs):
    # get_or_create makes this safe to fire on every save (signal also runs on profile updates)
    BuyerProfile.objects.get_or_create(user=instance)
