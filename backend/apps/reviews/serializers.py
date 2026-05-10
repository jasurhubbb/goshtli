"""Review serializers — create only allowed for buyer of a DELIVERED order; reads expose the denormalized fields."""
from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied

from apps.orders.models import Order
from .models import Review


class ReviewSerializer(serializers.ModelSerializer):
    """Public-safe read shape — buyer email + rating + comment + order id."""
    buyer_email = serializers.EmailField(source="buyer.email", read_only=True)
    supplier_email = serializers.EmailField(source="supplier.email", read_only=True)
    order_id = serializers.IntegerField(source="order.id", read_only=True)

    class Meta:
        model = Review
        fields = ("id", "order_id", "buyer_email", "supplier_email", "rating", "comment", "created_at")
        read_only_fields = ("id", "order_id", "buyer_email", "supplier_email", "created_at")


class ReviewCreateSerializer(serializers.Serializer):
    """Inputs for POST /reviews/ — order ID + rating + optional comment. Validates DELIVERED + buyer ownership."""
    order = serializers.IntegerField(min_value=1)
    rating = serializers.IntegerField(min_value=1, max_value=5)
    comment = serializers.CharField(max_length=2000, required=False, allow_blank=True, default="")

    def validate(self, attrs):
        # The view passes the request user in via context['request'] (DRF default)
        request = self.context["request"]
        try: order = Order.objects.select_related("listing").get(pk=attrs["order"])
        except Order.DoesNotExist: raise serializers.ValidationError({"order": "Order not found."})
        if order.buyer_id != request.user.id:
            raise PermissionDenied("You can only review your own orders.")
        if order.status != Order.Status.DELIVERED:
            raise serializers.ValidationError({"order": "Reviews are only allowed for DELIVERED orders."})
        if Review.objects.filter(order=order).exists():
            raise serializers.ValidationError({"order": "You have already reviewed this order."})
        attrs["_order_obj"] = order
        return attrs

    def create(self, validated_data):
        order = validated_data.pop("_order_obj")
        validated_data.pop("order")
        return Review.objects.create(order=order, buyer=order.buyer, supplier=order.listing.supplier, **validated_data)
