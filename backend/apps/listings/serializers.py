"""Listing serializers — v2 adds photo gallery + halal/freshness/cold-chain fields + supplier verification flag."""
from rest_framework import serializers
from .models import Listing, ListingPhoto


class ListingPhotoSerializer(serializers.ModelSerializer):
    """One image attached to a listing. url is the absolute URL the mobile app can directly render."""
    url = serializers.SerializerMethodField()

    class Meta:
        model = ListingPhoto
        fields = ("id", "url", "position")
        read_only_fields = fields

    def get_url(self, obj):
        request = self.context.get("request")
        if not obj.image: return ""
        # build_absolute_uri turns "/media/listings/3/foo.jpg" into "https://goshtli.../media/listings/3/foo.jpg"
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url


class ListingSerializer(serializers.ModelSerializer):
    """Read/write — supplier_id taken from request.user in the view, never accepted from input."""
    supplier_email = serializers.EmailField(source="supplier.email", read_only=True)
    supplier_business_name = serializers.CharField(source="supplier.supplier_profile.business_name",
                                                   read_only=True, default="")
    supplier_verified = serializers.BooleanField(source="supplier.supplier_profile.is_verified",
                                                 read_only=True, default=False)
    photos = ListingPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = Listing
        fields = ("id", "supplier_email", "supplier_business_name", "supplier_verified",
                  "title", "meat_type", "quantity_kg", "price_per_kg", "location",
                  "available_from", "description", "status",
                  "halal_certified", "freshness_date", "cold_chain", "service_area_csv",
                  "photos",
                  "created_at", "updated_at")
        read_only_fields = ("id", "supplier_email", "supplier_business_name", "supplier_verified",
                            "photos", "created_at", "updated_at")
        # status is editable so supplier can flip ACTIVE↔INACTIVE; SOLD_OUT transitions are managed by the orders service
