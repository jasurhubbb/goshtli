"""Listing serializers — public read shape vs. supplier-only write shape (supplier ID is forced from request.user)."""
from rest_framework import serializers
from .models import Listing


class ListingSerializer(serializers.ModelSerializer):
    """Read/write serializer — supplier_id is set from request.user in the view, never accepted from input."""
    supplier_email = serializers.EmailField(source="supplier.email", read_only=True)
    supplier_business_name = serializers.CharField(source="supplier.supplier_profile.business_name",
                                                   read_only=True, default="")

    class Meta:
        model = Listing
        fields = ("id", "supplier_email", "supplier_business_name", "title", "meat_type",
                  "quantity_kg", "price_per_kg", "location", "available_from", "description",
                  "status", "created_at", "updated_at")
        read_only_fields = ("id", "supplier_email", "supplier_business_name", "created_at", "updated_at")
        # status is editable so supplier can flip ACTIVE↔INACTIVE; SOLD_OUT transitions are managed by the orders service
