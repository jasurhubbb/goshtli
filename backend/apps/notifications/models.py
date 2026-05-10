"""Notification + DeviceToken — in-app rows + Firebase device tokens used to wake the phone via FCM."""
from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


class Notification(TimeStampedModel):
    class Kind(models.TextChoices):
        # Closed enum so future code can branch on category (icon, deep link target). Keep aligned with signals.py
        SUPPLIER_VERIFIED = "SUPPLIER_VERIFIED", _("Supplier verified")
        ORDER_PLACED = "ORDER_PLACED", _("Order placed")
        ORDER_STATUS_CHANGED = "ORDER_STATUS_CHANGED", _("Order status changed")
        ORDER_CANCELLED = "ORDER_CANCELLED", _("Order cancelled")
        OTHER = "OTHER", _("Other")

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="notifications", db_index=True)
    kind = models.CharField(_("kind"), max_length=24, choices=Kind.choices, default=Kind.OTHER)
    title = models.CharField(_("title"), max_length=200)
    message = models.TextField(_("message"), blank=True)
    # Generic deep-link target — frontend uses this to route to the related entity (e.g. /orders/123)
    link = models.CharField(_("deep link"), max_length=200, blank=True)
    is_read = models.BooleanField(_("is read"), default=False, db_index=True)

    class Meta:
        verbose_name = _("notification")
        verbose_name_plural = _("notifications")
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("user", "is_read"))]  # supports the unread-count query path

    def __str__(self): return f"[{'·' if self.is_read else '●'}] {self.title} → {self.user.email}"


class DeviceToken(TimeStampedModel):
    """One row per (user, FCM token) — used to fan out push messages on order/notification events.

    Token is unique globally — Firebase guarantees each install gets its own token. Reinstalling the app produces a
    fresh token, so old DeviceToken rows quietly become invalid (FCM returns NOT_REGISTERED on send → we delete).
    """
    class Platform(models.TextChoices):
        ANDROID = "ANDROID", _("Android")
        IOS = "IOS", _("iOS")
        WEB = "WEB", _("Web")

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="device_tokens", db_index=True)
    token = models.CharField(_("FCM token"), max_length=512, unique=True)
    platform = models.CharField(_("platform"), max_length=10, choices=Platform.choices, default=Platform.ANDROID)

    class Meta:
        verbose_name = _("device token")
        verbose_name_plural = _("device tokens")
        ordering = ("-updated_at",)

    def __str__(self): return f"{self.platform} token for {self.user.email}"
