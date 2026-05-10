"""Conversation + Message — 1:1 chat between users.

Conversation is keyed by (user_a, user_b) where user_a.id < user_b.id (enforced at create time) so we never end up
with two conversation rows for the same pair. get_or_create_for() in services handles the ordering.
"""
from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.common.models import TimeStampedModel


class Conversation(TimeStampedModel):
    """Holds the two participants + a denormalized last_message_at for cheap conversation-list ordering."""
    user_a = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                               related_name="conversations_as_a", db_index=True)
    user_b = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                               related_name="conversations_as_b", db_index=True)
    last_message_at = models.DateTimeField(_("last activity"), null=True, blank=True, db_index=True)

    class Meta:
        verbose_name = _("conversation")
        verbose_name_plural = _("conversations")
        ordering = ("-last_message_at", "-created_at")
        # Composite unique on the ordered pair — get_or_create_for enforces user_a.id < user_b.id at the service layer
        constraints = [models.UniqueConstraint(fields=("user_a", "user_b"), name="uniq_conversation_pair")]

    def other_user(self, current):
        """Return the participant who isn't `current` — convenience for serializers."""
        return self.user_b if self.user_a_id == current.id else self.user_a

    def __str__(self): return f"Conv {self.user_a.email} ↔ {self.user_b.email}"


class Message(TimeStampedModel):
    """One chat message. read_by_recipient flips True when the other user fetches /messages/ (eager-read v2)."""
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages", db_index=True)
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                               related_name="messages_sent", db_index=True)
    text = models.TextField(_("text"))
    read_by_recipient = models.BooleanField(_("read"), default=False, db_index=True)

    class Meta:
        verbose_name = _("message")
        verbose_name_plural = _("messages")
        ordering = ("created_at",)  # ascending — chat UIs render in time order

    def __str__(self): return f"#{self.pk} {self.sender.email}: {self.text[:40]}"
