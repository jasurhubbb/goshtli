"""Order serializers — split between create (write-only inputs) and read (full nested view)."""
from decimal import Decimal
from rest_framework import serializers
from .models import Order


class OrderReadSerializer(serializers.ModelSerializer):
    """Used by all GET endpoints and as the response after create/cancel/status updates.

    v3.1: listing_title → listing_name_uz/ru (matches the new bilingual schema). The legacy meat_type field is
    replaced by listing_category_slug — clients render a localized label via the categories endpoint.
    v3.6: adds listing.is_live_animal + listing.sale_type so the mobile order list/detail screens can render
    the correct iconography (refrigerator-truck vs chorva-taksi) and live-animal badges per PRD §3.
    """
    supplier_user_id = serializers.IntegerField(source="listing.supplier.id", read_only=True)
    listing_name_uz = serializers.CharField(source="listing.name_uz", read_only=True)
    listing_name_ru = serializers.CharField(source="listing.name_ru", read_only=True)
    listing_category_slug = serializers.CharField(source="listing.category.slug", read_only=True, default="")
    listing_market_slug = serializers.CharField(source="listing.market.slug", read_only=True, default="")
    listing_is_live_animal = serializers.BooleanField(source="listing.is_live_animal", read_only=True)
    listing_sale_type = serializers.CharField(source="listing.sale_type", read_only=True)
    listing_price_per_kg = serializers.DecimalField(source="listing.price_per_kg", read_only=True,
                                                    max_digits=10, decimal_places=2)
    # v3.7 — display-friendly names that the mobile "Kimdan / Kimga" rows now show. Email is kept for
    # backward compatibility (chat / admin code paths still reference it) but the buyer-facing UI never
    # surfaces it — synthetic `<phone>@phone.goshtli.local` strings are ugly and leak the auth scheme.
    seller_name_uz = serializers.CharField(source="listing.market.name_uz", read_only=True, default="")
    seller_name_ru = serializers.CharField(source="listing.market.name_ru", read_only=True, default="")
    buyer_name = serializers.CharField(source="buyer.full_name", read_only=True, default="")
    buyer_phone = serializers.CharField(source="buyer.phone", read_only=True, default="")
    buyer_email = serializers.EmailField(source="buyer.email", read_only=True)
    supplier_email = serializers.EmailField(source="listing.supplier.email", read_only=True)
    # v3.9.16 — delivery/courier info for the buyer's confirm-order page: the proof photo the courier
    # uploaded + the delivery person's name/phone (so the buyer can view the drop-off shot and call them).
    # Empty until an order is dispatched (a Delivery exists with a real courier or a self-delivering supplier).
    delivery_proof_url = serializers.SerializerMethodField()
    courier_name = serializers.SerializerMethodField()
    courier_phone = serializers.SerializerMethodField()

    def _delivery(self, obj):
        return getattr(obj, "delivery", None)

    def _delivery_contact(self, obj):
        d = self._delivery(obj)
        if not d or d.courier is None:
            return None
        c = d.courier
        # The person delivering: a real platform courier, or a self-delivering supplier. The admin fallback
        # stub (neither) is treated as "not assigned yet" → no contact shown.
        if c.id == obj.listing.supplier_id or getattr(c, "is_courier", False):
            cp = getattr(c, "courier_profile", None)
            name = (cp.full_name if cp and cp.full_name else "") or c.full_name or "Kuryer"
            return {"name": name, "phone": c.phone or ""}
        return None

    def get_delivery_proof_url(self, obj):
        d = self._delivery(obj)
        if not d or not d.proof_photo:
            return ""
        request = self.context.get("request")
        url = d.proof_photo.url
        return request.build_absolute_uri(url) if request else url

    def get_courier_name(self, obj):
        info = self._delivery_contact(obj)
        return info["name"] if info else ""

    def get_courier_phone(self, obj):
        info = self._delivery_contact(obj)
        return info["phone"] if info else ""

    class Meta:
        model = Order
        fields = ("id", "buyer_email", "supplier_email", "supplier_user_id",
                  # v3.7 display-friendly identity fields — buyer/seller-facing UI uses these.
                  "buyer_name", "buyer_phone", "seller_name_uz", "seller_name_ru",
                  "listing", "listing_name_uz", "listing_name_ru",
                  "listing_category_slug", "listing_market_slug",
                  "listing_is_live_animal", "listing_sale_type",
                  "listing_price_per_kg",
                  "quantity_kg", "total_price", "delivery_address", "notes", "status",
                  # v3.5 payment fields — let the mobile app branch on payment_status to either show
                  # the WebView (UNPAID/PENDING) or the success/failure screen (PAID/FAILED).
                  "payment_status", "payment_url",
                  # v3.6 delivery + butcher fields — mobile order detail renders the timeline with these.
                  "delivery_vehicle_type", "delivery_time_slot", "delivery_distance_km",
                  "delivery_lat", "delivery_lng", "delivery_price",
                  "butcher_service_requested", "butcher_service_fee",
                  # v3.9.15 — expose both qassob FKs so the buyer's order detail can render "Sizning
                  # tanlagan qassob: <name>" (preferred) and "Qabul qilgan qassob: <name>" (assigned).
                  "preferred_qassob", "assigned_qassob",
                  # v3.9.16 — courier proof photo + delivery-person contact for the confirm-order page.
                  "delivery_proof_url", "courier_name", "courier_phone",
                  "created_at", "updated_at")
        read_only_fields = fields  # read serializer — no field is writable here


class OrderCreateSerializer(serializers.Serializer):
    """Strictly-typed input shape for POST /orders/. The view passes these fields to create_order() in the service.

    v3.6 per PRD: optional delivery_* and butcher_service_* fields land here so the mobile delivery page can
    post a fully-formed order in one round-trip. They're optional at the serializer layer (back-compat with
    legacy callers that posted only listing/quantity/delivery_address) and DEFAULTED in the service.
    """
    listing = serializers.IntegerField(min_value=1)              # listing PK
    quantity_kg = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))
    delivery_address = serializers.CharField(max_length=1000)
    notes = serializers.CharField(max_length=2000, required=False, allow_blank=True, default="")

    # v3.6 delivery fields — all optional at the wire level so the model layer can decide defaults; the
    # mobile Delivery page posts them all together.
    delivery_vehicle_type = serializers.ChoiceField(choices=Order.VehicleType.choices, required=False,
                                                    allow_blank=True, default="")
    delivery_time_slot = serializers.ChoiceField(choices=Order.TimeSlot.choices, required=False,
                                                 allow_blank=True, default="")
    delivery_distance_km = serializers.DecimalField(max_digits=8, decimal_places=2, required=False,
                                                     default=Decimal("0.00"))
    delivery_lat = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True,
                                             default=None)
    delivery_lng = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True,
                                             default=None)
    delivery_price = serializers.DecimalField(max_digits=12, decimal_places=2, required=False,
                                               default=Decimal("0.00"))
    butcher_service_requested = serializers.BooleanField(required=False, default=False)
    butcher_service_fee = serializers.DecimalField(max_digits=12, decimal_places=2, required=False,
                                                    default=Decimal("0.00"))
    # v3.9.15 — buyer's preferred qassob (User pk). Passed only for live-animal orders with the
    # butcher service requested. The service layer soft-reserves this qassob for 60s before fanning
    # the job out to the wider matching pool.
    preferred_qassob = serializers.IntegerField(required=False, allow_null=True, default=None)


class OrderStatusUpdateSerializer(serializers.Serializer):
    """Input shape for POST /orders/supplier/{id}/status/ — only one field but kept as serializer for validation parity."""
    status = serializers.ChoiceField(choices=Order.Status.choices)
