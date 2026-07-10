"""TelegramVerification — one row per phone-verification attempt.

Lifecycle:
  AWAITING_CONTACT  app posted the phone via /auth/telegram/start/; waiting for the user to share their
                    contact inside the bot. (`session_token` is the deep-link ?start= payload.)
  CODE_SENT         bot matched the shared (Telegram-verified) phone to this row + sent a 6-digit code.
  VERIFIED          the user entered the correct code in the app; row is consumed (single-use).

We keep the code only as an HMAC digest (see otp.hash_code) with a 5-minute TTL + a 5-attempt cap. On resend we
create a fresh row and let the newest AWAITING_CONTACT/CODE_SENT row for a phone win, so only the latest code is
ever valid (older rows are ignored + swept).
"""
from django.db import models

from apps.common.models import TimeStampedModel


class TelegramVerification(TimeStampedModel):
    class Status(models.TextChoices):
        AWAITING_CONTACT = "AWAITING_CONTACT", "Awaiting contact share"
        CODE_SENT = "CODE_SENT", "Code sent"
        VERIFIED = "VERIFIED", "Verified"

    # Canonical E.164 phone the app claims. Indexed because the webhook looks rows up by phone when a contact
    # is shared, and the verify endpoint / rate-limiter scan by phone.
    phone = models.CharField(max_length=20, db_index=True)
    # Deep-link ?start= payload — unique so the bot can correlate a /start back to the exact app session.
    session_token = models.CharField(max_length=64, unique=True, db_index=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.AWAITING_CONTACT,
                              db_index=True)

    # HMAC-SHA256 digest of the code (empty until the bot sends one). Never the plaintext code.
    code_hash = models.CharField(max_length=64, blank=True)
    attempts = models.PositiveSmallIntegerField(default=0)          # wrong verify attempts against code_hash
    code_sent_at = models.DateTimeField(null=True, blank=True)      # anchors the resend cooldown / hourly cap
    code_expires_at = models.DateTimeField(null=True, blank=True)   # code_sent_at + 5 min
    consumed_at = models.DateTimeField(null=True, blank=True)       # set on successful verify (single-use gate)

    # Telegram identity captured at contact-share time (for auditing + so we could re-message the same chat).
    telegram_user_id = models.BigIntegerField(null=True, blank=True)
    telegram_chat_id = models.BigIntegerField(null=True, blank=True)

    class Meta:
        verbose_name = "Telegram verification"
        verbose_name_plural = "Telegram verifications"
        ordering = ("-created_at",)
        indexes = [models.Index(fields=("phone", "status")),
                   models.Index(fields=("phone", "code_sent_at"))]

    def __str__(self):
        return f"TelegramVerification({self.phone}, {self.status})"
