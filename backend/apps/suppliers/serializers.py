"""Supplier serializers — profile shape returned by /suppliers/me/, plus the dashboard aggregate."""
from rest_framework import serializers
from .models import SupplierProfile


class SupplierProfileSerializer(serializers.ModelSerializer):
    """Public-safe profile representation. is_verified is read-only — only admin can change it (via Django Admin)."""
    email = serializers.EmailField(source="user.email", read_only=True)
    full_name = serializers.CharField(source="user.full_name", read_only=True)

    class Meta:
        model = SupplierProfile
        fields = ("id", "email", "full_name", "business_name", "region", "address",
                  "is_verified", "created_at", "updated_at")
        read_only_fields = ("id", "is_verified", "created_at", "updated_at")


class SupplierDashboardSerializer(serializers.Serializer):
    """Aggregate metrics for the supplier home screen — listing counts by status + order counts by status."""
    is_verified = serializers.BooleanField()
    listings_total = serializers.IntegerField()
    listings_active = serializers.IntegerField()
    listings_sold_out = serializers.IntegerField()
    listings_inactive = serializers.IntegerField()
    orders_pending = serializers.IntegerField()
    orders_in_progress = serializers.IntegerField()  # CONFIRMED + PROCESSING + IN_TRANSIT collapsed for the UI
    orders_delivered = serializers.IntegerField()
    orders_cancelled = serializers.IntegerField()
