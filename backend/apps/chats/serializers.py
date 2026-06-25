"""Chat serializers — conversation summary (for the list view) + message shape."""
from rest_framework import serializers

from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    sender_email = serializers.EmailField(source="sender.email", read_only=True)

    class Meta:
        model = Message
        fields = ("id", "sender_email", "text", "read_by_recipient", "created_at")
        read_only_fields = ("id", "sender_email", "read_by_recipient", "created_at")


class ConversationSerializer(serializers.ModelSerializer):
    """Compact summary used by the conversation list — other-user info + last message preview + unread count.

    v3.9.8: also surfaces last_message_sender_name + last_message_is_mine so the buyer/qassob chat
    list can render "[OtherName]\\n[YouOrTheirName]: message…" rows in the WhatsApp/Telegram style
    without a second roundtrip for the message metadata.
    """
    other_user_id = serializers.SerializerMethodField()
    other_user_email = serializers.SerializerMethodField()
    other_user_name = serializers.SerializerMethodField()
    last_message_preview = serializers.SerializerMethodField()
    last_message_sender_name = serializers.SerializerMethodField()
    last_message_is_mine = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ("id", "other_user_id", "other_user_email", "other_user_name",
                  "last_message_at", "last_message_preview",
                  "last_message_sender_name", "last_message_is_mine",
                  "unread_count")
        read_only_fields = fields

    def _other(self, obj):
        request = self.context.get("request")
        return obj.other_user(request.user) if request else obj.user_b

    def _last(self, obj):
        # Cached on the instance so multiple SerializerMethodFields don't N+1 the same lookup. None
        # when the conversation has no messages (newly-started chat).
        if not hasattr(obj, "_cached_last"):
            obj._cached_last = obj.messages.select_related("sender").order_by("-created_at").first()
        return obj._cached_last

    def get_other_user_id(self, obj): return self._other(obj).id
    def get_other_user_email(self, obj): return self._other(obj).email
    def get_other_user_name(self, obj): return self._other(obj).full_name

    def get_last_message_preview(self, obj):
        last = self._last(obj)
        return (last.text[:80] if last else "")

    def get_last_message_sender_name(self, obj):
        last = self._last(obj)
        if last is None:
            return ""
        return last.sender.full_name or last.sender.email

    def get_last_message_is_mine(self, obj):
        request = self.context.get("request")
        last = self._last(obj)
        if last is None or request is None: return False
        return last.sender_id == request.user.id

    def get_unread_count(self, obj):
        request = self.context.get("request")
        if not request: return 0
        return obj.messages.exclude(sender=request.user).filter(read_by_recipient=False).count()
