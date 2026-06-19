"""DRF serializers for QassobProfile.

Two shapes:
  • QassobPublicSerializer — buyer-app Servislar tab. No phone if phone_visible=False, no internal flags.
  • QassobMeSerializer — partner-app /qassobs/me/. Owner's full editable view.

Wire validation: `animals_supported` and `delivery_modes` come from the wizard as JSON lists; we
re-validate that every value is in VALID_ANIMAL_CODES before save so a stale mobile build can't poison
the DB with unknown codes.
"""
from rest_framework import serializers

from .models import QassobProfile, VALID_ANIMAL_CODES


def _validate_animal_codes(value):
    """Common validator for animals_supported lists. Raises if any code is unknown."""
    if not isinstance(value, list):
        raise serializers.ValidationError("Must be a list of animal codes.")
    bad = [c for c in value if c not in VALID_ANIMAL_CODES]
    if bad:
        raise serializers.ValidationError(
            f"Unknown animal codes: {bad}. Allowed: {sorted(VALID_ANIMAL_CODES)}.")
    return value


class QassobMeSerializer(serializers.ModelSerializer):
    """Owner-side CRUD shape. PATCH from the partner-app Profile screen lands here. `is_verified` is
    read-only — only admin flips it from Django Admin after KYC review."""

    photo_url = serializers.SerializerMethodField()
    email = serializers.EmailField(source="user.email", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)

    class Meta:
        model = QassobProfile
        fields = ("id", "email", "phone",
                  "full_name", "years_experience",
                  "region", "address", "lat", "lng", "service_radius_km",
                  "animals_supported", "is_slaughterhouse", "daily_capacity_head",
                  "photo", "photo_url",
                  "phone_visible", "telegram_username",
                  "is_open_now", "rating_avg", "rating_count", "is_verified",
                  "created_at", "updated_at")
        read_only_fields = ("id", "email", "phone", "rating_avg", "rating_count",
                            "is_verified", "photo_url", "created_at", "updated_at")

    def get_photo_url(self, obj):
        if not obj.photo: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.photo.url) if req else obj.photo.url

    def validate_animals_supported(self, v): return _validate_animal_codes(v)


class QassobPublicSerializer(serializers.ModelSerializer):
    """Buyer-app Servislar tab + detail. Hides admin/internal fields. Phone only included when
    `phone_visible` is True. Computes `distance_km` when the request supplies buyer lat/lng query params."""

    photo_url = serializers.SerializerMethodField()
    phone = serializers.SerializerMethodField()
    telegram = serializers.CharField(source="telegram_username", read_only=True)
    distance_km = serializers.SerializerMethodField()

    class Meta:
        model = QassobProfile
        fields = ("id", "full_name", "years_experience",
                  "region", "address", "lat", "lng", "service_radius_km",
                  "animals_supported", "is_slaughterhouse",
                  "photo_url", "phone", "telegram",
                  "is_open_now", "rating_avg", "rating_count", "distance_km")
        read_only_fields = fields

    def get_photo_url(self, obj):
        if not obj.photo: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.photo.url) if req else obj.photo.url

    def get_phone(self, obj):
        if not obj.phone_visible: return ""
        return obj.user.phone or ""

    def get_distance_km(self, obj):
        """Compute haversine distance from the request's `buyer_lat`/`buyer_lng` query params, if both
        are present. Lets the buyer-app sort by distance without a second backend call."""
        req = self.context.get("request")
        if not req: return None
        try:
            blat = float(req.query_params.get("buyer_lat", ""))
            blng = float(req.query_params.get("buyer_lng", ""))
        except (TypeError, ValueError):
            return None
        if obj.lat is None or obj.lng is None: return None
        import math
        r = 6371.0
        lat1, lat2 = math.radians(float(obj.lat)), math.radians(blat)
        dlat = math.radians(blat - float(obj.lat))
        dlng = math.radians(blng - float(obj.lng))
        a = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlng/2)**2
        return round(2 * r * math.asin(math.sqrt(a)), 2)


class AvailabilityToggleSerializer(serializers.Serializer):
    """POST /qassobs/me/availability/ — F1 Open/Closed quiet-hours."""
    is_open_now = serializers.BooleanField()


class CapacityUpdateSerializer(serializers.Serializer):
    """POST /qassobs/me/capacity/ — F8 daily capacity slider."""
    daily_capacity_head = serializers.IntegerField(min_value=1, max_value=200)
