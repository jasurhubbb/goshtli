"""Order serializers — split between create (write-only inputs) and read (full nested view)."""
from decimal import Decimal
from rest_framework import serializers
from .models import Order


class OrderReadSerializer(serializers.ModelSerializer):
    """Used by all GET endpoints and as the response after create/cancel/status updates."""
    supplier_user_id = serializers.IntegerField(source="listing.supplier.id", read_only=True)
    listing_title = serializers.CharField(source="listing.title", read_only=True)
    listing_meat_type = serializers.CharField(source="listing.meat_type", read_only=True)
    listing_price_per_kg = serializers.DecimalField(source="listing.price_per_kg", read_only=True,
                                                    max_digits=10, decimal_places=2)
    buyer_email = serializers.EmailField(source="buyer.email", read_only=True)
    supplier_email = serializers.EmailField(source="listing.supplier.email", read_only=True)

    class Meta:
        model = Order
        fields = ("id", "buyer_email", "supplier_email", "supplier_user_id",
                  "listing", "listing_title", "listing_meat_type", "listing_price_per_kg",
                  "quantity_kg", "total_price", "delivery_address", "notes", "status",
                  "created_at", "updated_at")
        read_only_fields = fields  # read serializer — no field is writable here


class OrderCreateSerializer(serializers.Serializer):
    """Strictly-typed input shape for POST /orders/. The view passes these fields to create_order() in the service."""
    listing = serializers.IntegerField(min_value=1)              # listing PK
    quantity_kg = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))
    delivery_address = serializers.CharField(max_length=1000)
    notes = serializers.CharField(max_length=2000, required=False, allow_blank=True, default="")


class OrderStatusUpdateSerializer(serializers.Serializer):
    """Input shape for POST /orders/supplier/{id}/status/ — only one field but kept as serializer for validation parity."""
    status = serializers.ChoiceField(choices=Order.Status.choices)
