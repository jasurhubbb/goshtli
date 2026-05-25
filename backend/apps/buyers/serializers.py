"""Buyer serializers — profile shape for /buyers/me/, dashboard aggregate, saved-address CRUD."""
from rest_framework import serializers
from .models import BuyerProfile, SavedAddress


class SavedAddressSerializer(serializers.ModelSerializer):
    """Full address shape exposed to the mobile app. The new (v3.1) hint + geo fields are writeable;
    timestamps + id stay read-only."""
    class Meta:
        model = SavedAddress
        fields = ("id", "label", "address",
                  "entrance", "floor", "apartment", "notes",
                  "lat", "lng",
                  "is_default", "created_at", "updated_at")
        read_only_fields = ("id", "created_at", "updated_at")


class BuyerProfileSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(source="user.email", read_only=True)
    full_name = serializers.CharField(source="user.full_name", read_only=True)

    class Meta:
        model = BuyerProfile
        fields = ("id", "email", "full_name", "business_name", "region", "address", "created_at", "updated_at")
        read_only_fields = ("id", "created_at", "updated_at")


class BuyerDashboardSerializer(serializers.Serializer):
    """Order-status counts for the buyer home screen — same in-progress collapsing as the supplier dashboard for symmetry."""
    orders_pending = serializers.IntegerField()
    orders_in_progress = serializers.IntegerField()
    orders_delivered = serializers.IntegerField()
    orders_cancelled = serializers.IntegerField()
