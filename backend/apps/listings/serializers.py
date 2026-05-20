"""Listing serializers — v3.1 catalog overhaul.

Wire shape exposed to the mobile app:
  • Core identity: id, slug, name_uz, name_ru, description_uz, description_ru
  • Pricing/inventory: price_per_kg, quantity_kg, status
  • Vendor: nested market summary (id, slug, name_uz, name_ru, region, logo_url)
  • Category: nested category summary (slug, name_uz, name_ru, image_url)
  • Photos: list of ListingPhoto rows
  • Audit timestamps: created_at, updated_at

The legacy `supplier_*` fields are kept (read-only) so existing mobile/chat code that references them keeps
working — they'll be removed in a follow-up when the mobile side has been migrated to read market.* instead.
"""
from rest_framework import serializers

from apps.markets.models import Market
from .models import Listing, ListingPhoto, MeatCategory


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
        # build_absolute_uri turns "/media/listings/3/foo.jpg" into "https://api.../media/listings/3/foo.jpg"
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url


class MeatCategoryNestedSerializer(serializers.ModelSerializer):
    """Compact category embed used inside ListingSerializer — buyers only need name+slug+image to render the chip."""
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = MeatCategory
        fields = ("slug", "name_uz", "name_ru", "image_url")
        read_only_fields = fields

    def get_image_url(self, obj):
        request = self.context.get("request")
        if not obj.image: return ""
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url


class MarketNestedSerializer(serializers.ModelSerializer):
    """Compact market embed used inside ListingSerializer — buyers see "from <Market> in <region>" on each card."""
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = Market
        fields = ("id", "slug", "name_uz", "name_ru", "region", "logo_url", "is_active")
        read_only_fields = fields

    def get_logo_url(self, obj):
        request = self.context.get("request")
        if not obj.logo: return ""
        return request.build_absolute_uri(obj.logo.url) if request else obj.logo.url


class ListingSerializer(serializers.ModelSerializer):
    """Read/write — supplier_id taken from request.user in the view, never accepted from input.

    Writes accept FK IDs (market_id, category_id); reads expand them into nested summaries so the mobile app
    doesn't need a second round-trip to render a product card."""

    # ---- Read-only nested embeds (returned in responses) ----
    market = MarketNestedSerializer(read_only=True)
    category = MeatCategoryNestedSerializer(read_only=True)
    photos = ListingPhotoSerializer(many=True, read_only=True)

    # ---- Write-only FK inputs (accepted in POST/PATCH) ----
    market_id = serializers.PrimaryKeyRelatedField(
        queryset=Market.objects.all(), source="market", write_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=MeatCategory.objects.all(), source="category", write_only=True)

    # ---- Legacy supplier embeds (still used by chat / order code paths) ----
    supplier_id = serializers.IntegerField(source="supplier.id", read_only=True)
    supplier_email = serializers.EmailField(source="supplier.email", read_only=True)

    class Meta:
        model = Listing
        fields = ("id", "slug",
                  "market", "category", "market_id", "category_id",
                  "name_uz", "name_ru", "description_uz", "description_ru",
                  "quantity_kg", "price_per_kg", "location", "available_from", "status",
                  "supplier_id", "supplier_email",
                  "photos",
                  "created_at", "updated_at")
        read_only_fields = ("id", "slug", "supplier_id", "supplier_email", "market", "category",
                            "photos", "created_at", "updated_at")
