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
    """Compact summary used by the conversation list — other-user info + last message preview + unread count."""
    other_user_id = serializers.SerializerMethodField()
    other_user_email = serializers.SerializerMethodField()
    other_user_name = serializers.SerializerMethodField()
    last_message_preview = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ("id", "other_user_id", "other_user_email", "other_user_name",
                  "last_message_at", "last_message_preview", "unread_count")
        read_only_fields = fields

    def _other(self, obj):
        request = self.context.get("request")
        return obj.other_user(request.user) if request else obj.user_b

    def get_other_user_id(self, obj): return self._other(obj).id
    def get_other_user_email(self, obj): return self._other(obj).email
    def get_other_user_name(self, obj): return self._other(obj).full_name

    def get_last_message_preview(self, obj):
        last = obj.messages.order_by("-created_at").first()
        return (last.text[:80] if last else "")

    def get_unread_count(self, obj):
        request = self.context.get("request")
        if not request: return 0
        return obj.messages.exclude(sender=request.user).filter(read_by_recipient=False).count()
