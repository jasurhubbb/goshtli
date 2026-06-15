"""Card — a saved payment card for one buyer. PCI-clean: we NEVER store the full PAN or CVC.

Why this model exists even in mock mode: the wire shape (id, last_4, brand, expiry, holder) is identical
to what Payme's saved-cards API returns, so the mobile UI, the profile "Mening kartalarim" section, and
the checkout picker all work end-to-end against fake data today AND against the real Payme API tomorrow
without a schema change. When we switch PAYMENT_PROVIDER=mock → payme, only the provider adapter sees
the difference; the rest of the stack keeps reading from `Card`.

What we keep:
  last_4 + brand                 — for the UI ("•••• 4242 HUMO")
  expires_month/year             — for the UI expiry strip + soft "this card is expired" check
  holder_name                    — printed on the card; cosmetic, not used for routing
  phone_for_sms                  — Payme delivers the 3DS-style OTP to this phone; we keep it for parity
                                   with the real flow even though the mock provider never sends an SMS
  is_default                     — single-flag "use this card first on the picker"
  provider + provider_card_token — placeholder for when real Payme issues a token after first-charge save

What we DON'T keep: the full PAN, the CVC, the magstripe/chip data. Even in mock mode. So the field set
is forward-compatible with PCI-DSS without us having to scrub anything when going live.
"""
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator, RegexValidator
from django.db import models, transaction
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


class Card(TimeStampedModel):
    """One saved card belonging to one user. Multiple cards per user allowed; exactly one `is_default`."""

    class Brand(models.TextChoices):
        # Uzbekistan-issued local cards (the majority of buyers will use one of these two).
        HUMO = "HUMO", _("HUMO")
        UZCARD = "UZCARD", _("UZCARD")
        # International schemes — supported via Payme's international rails for cross-border buyers.
        VISA = "VISA", _("Visa")
        MASTERCARD = "MASTERCARD", _("Mastercard")
        # Fallback when the BIN doesn't match any known prefix. UI shows a generic card icon.
        UNKNOWN = "UNKNOWN", _("Unknown")

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="payment_cards", db_index=True)
    # last 4 digits of the PAN — the only PAN substring we EVER persist. Display-only.
    last_4 = models.CharField(_("last 4 digits"), max_length=4,
                              validators=[RegexValidator(r"^\d{4}$", "Must be 4 digits.")])
    brand = models.CharField(_("brand"), max_length=12, choices=Brand.choices, default=Brand.UNKNOWN)
    expires_month = models.PositiveSmallIntegerField(_("expires month"),
                                                     validators=[MinValueValidator(1), MaxValueValidator(12)])
    expires_year = models.PositiveSmallIntegerField(_("expires year (YYYY)"),
                                                    validators=[MinValueValidator(2024), MaxValueValidator(2099)])
    holder_name = models.CharField(_("holder name"), max_length=80, blank=True)
    # Uzbek phone the SMS-OTP would be delivered to. Stored even in mock so the real-Payme switch is a no-op.
    phone_for_sms = models.CharField(_("phone for SMS"), max_length=20, blank=True,
                                     validators=[RegexValidator(r"^\+?\d{9,15}$", "Must be a phone number.")])
    is_default = models.BooleanField(_("default"), default=False, db_index=True)
    # Provider hooks — empty in mock mode, populated by PaymeProvider when we go live.
    provider = models.CharField(_("provider"), max_length=20, blank=True)
    provider_card_token = models.CharField(_("provider card token"), max_length=128, blank=True)

    class Meta:
        verbose_name = _("payment card")
        verbose_name_plural = _("payment cards")
        ordering = ("-is_default", "-created_at")
        constraints = [
            # Each user has at most ONE default card. Enforced at the DB level so a race between two
            # "set default" requests can't leave both marked default.
            models.UniqueConstraint(fields=["user"], condition=models.Q(is_default=True),
                                    name="uniq_default_card_per_user"),
        ]

    def __str__(self): return f"{self.brand} •••• {self.last_4} ({self.user.email})"

    @property
    def is_expired(self) -> bool:
        """Soft check used by the picker UI to grey out expired cards. We use end-of-month semantics —
        a card with 06/2026 is valid through 2026-06-30."""
        from datetime import date
        today = date.today()
        return (self.expires_year, self.expires_month) < (today.year, today.month)

    @transaction.atomic
    def make_default(self):
        """Atomic 'set this card as default' — unsets the previous default in the SAME transaction so
        the partial unique constraint above can't trip. Safe to call from a request handler."""
        Card.objects.filter(user=self.user, is_default=True).exclude(pk=self.pk).update(is_default=False)
        if not self.is_default:
            self.is_default = True
            self.save(update_fields=["is_default", "updated_at"])
