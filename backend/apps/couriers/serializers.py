"""DRF serializers for the courier surface — profile shape + delivery detail shape (with buyer +
listing + address embeds so the courier app never needs to N+1 back to orders/listings/users)."""
from rest_framework import serializers

from apps.orders.models import Order
from .models import CourierProfile, Delivery


class CourierMeSerializer(serializers.ModelSerializer):
    """Owner-side courier profile — read/write. photo is write-only; photo_url is the derived read."""
    email = serializers.EmailField(source="user.email", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)
    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = CourierProfile
        fields = ("id", "email", "phone", "full_name",
                  "vehicle_kind", "vehicle_plate", "is_online",
                  "photo", "photo_url",
                  "rating_avg", "rating_count",
                  "lifetime_deliveries", "lifetime_earnings_uzs",
                  "created_at", "updated_at")
        read_only_fields = ("id", "email", "phone",
                             "rating_avg", "rating_count",
                             "lifetime_deliveries", "lifetime_earnings_uzs",
                             "photo_url", "created_at", "updated_at")
        extra_kwargs = {"photo": {"write_only": True, "required": False}}

    def get_photo_url(self, obj):
        if not obj.photo: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.photo.url) if req else obj.photo.url


class DeliveryListSerializer(serializers.ModelSerializer):
    """Compact list shape for the courier's Queue tab. Renders as a single card per row with pickup
    address + drop-off address + total price. Every embed is cached in one query via select_related.
    """
    order_id = serializers.IntegerField(source="order.id", read_only=True)
    buyer_name = serializers.CharField(source="order.buyer.full_name", read_only=True)
    buyer_phone = serializers.CharField(source="order.buyer.phone", read_only=True)
    listing_name = serializers.CharField(source="order.listing.name_uz", read_only=True)
    quantity_kg = serializers.CharField(source="order.quantity_kg", read_only=True)
    total_price = serializers.CharField(source="order.total_price", read_only=True)
    dropoff_address = serializers.CharField(source="order.delivery_address", read_only=True)
    dropoff_lat = serializers.CharField(source="order.delivery_lat", read_only=True)
    dropoff_lng = serializers.CharField(source="order.delivery_lng", read_only=True)
    # Pickup = the supplier's market address (best proxy for now — later we'll add pickup_lat/lng
    # on Order for orders that ship from a warehouse). Nullable when the market has no address set.
    pickup_address = serializers.SerializerMethodField()
    pickup_lat = serializers.SerializerMethodField()
    pickup_lng = serializers.SerializerMethodField()

    class Meta:
        model = Delivery
        fields = ("id", "order_id", "status",
                  "buyer_name", "buyer_phone",
                  "listing_name", "quantity_kg", "total_price",
                  "pickup_address", "pickup_lat", "pickup_lng",
                  "dropoff_address", "dropoff_lat", "dropoff_lng",
                  "cash_collected_uzs", "payout_uzs",
                  "picked_up_at", "delivered_at",
                  "created_at")
        read_only_fields = fields

    def _market(self, obj):
        try: return obj.order.listing.market
        except Exception: return None

    def get_pickup_address(self, obj):
        # Supplier's market address. Fall back to region + market name when the street address is blank,
        # and finally to the market name, so the courier sees SOMETHING useful (a supplier who never set a
        # street address still shows e.g. "Toshkent · Sarvarbek go'sht") instead of an empty pickup line.
        m = self._market(obj)
        if not m:
            return ""
        addr = (m.address or "").strip()
        if addr:
            return addr
        parts = [p for p in ((m.region or "").strip(), (getattr(m, "name_uz", "") or "").strip()) if p]
        return " · ".join(parts)

    def get_pickup_lat(self, obj):
        m = self._market(obj)
        return str(m.lat) if m and m.lat is not None else ""

    def get_pickup_lng(self, obj):
        m = self._market(obj)
        return str(m.lng) if m and m.lng is not None else ""


class DeliveryDetailSerializer(DeliveryListSerializer):
    """Full shape for the courier's delivery-detail screen. Adds notes + payment status + buyer
    email so the courier has every piece of context in one round-trip. Extends DeliveryListSerializer
    so the field set stays in sync."""
    buyer_email = serializers.CharField(source="order.buyer.email", read_only=True)
    notes = serializers.CharField(source="order.notes", read_only=True)
    payment_status = serializers.CharField(source="order.payment_status", read_only=True)
    time_slot = serializers.CharField(source="order.delivery_time_slot", read_only=True)
    vehicle_type = serializers.CharField(source="order.delivery_vehicle_type", read_only=True)
    proof_photo_url = serializers.SerializerMethodField()

    class Meta(DeliveryListSerializer.Meta):
        fields = DeliveryListSerializer.Meta.fields + (
            "buyer_email", "notes", "payment_status",
            "time_slot", "vehicle_type", "proof_photo_url",
        )
        read_only_fields = fields

    def get_proof_photo_url(self, obj):
        if not obj.proof_photo: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.proof_photo.url) if req else obj.proof_photo.url


class DeliveryStatusUpdateSerializer(serializers.Serializer):
    """POST /couriers/me/deliveries/<id>/status/ — courier advances the delivery-side lifecycle.
    Allowed transitions guarded in the view."""
    status = serializers.ChoiceField(choices=Delivery.Status.choices)
    cash_collected_uzs = serializers.IntegerField(required=False, min_value=0)


class DeliveryProofUploadSerializer(serializers.Serializer):
    """POST /couriers/me/deliveries/<id>/proof/ — multipart photo upload for delivery confirmation."""
    proof_photo = serializers.ImageField(required=True)
