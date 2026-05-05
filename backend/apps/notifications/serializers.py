"""Notification serializers — read-mostly. Mutations only flip is_read."""
from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ("id", "kind", "title", "message", "link", "is_read", "created_at")
        read_only_fields = fields  # all fields read-only via this serializer; is_read flips via dedicated action endpoint
