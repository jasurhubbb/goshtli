"""DRF serializers for QassobProfile.

Two shapes:
  • QassobPublicSerializer — buyer-app Servislar tab. No phone if phone_visible=False, no internal flags.
  • QassobMeSerializer — partner-app /qassobs/me/. Owner's full editable view.

Wire validation: `animals_supported` and `delivery_modes` come from the wizard as JSON lists; we
re-validate that every value is in VALID_ANIMAL_CODES before save so a stale mobile build can't poison
the DB with unknown codes.

v3.9: adds the seven service-profile fields (bio/specialties/certifications/working_hours/price_list/
languages/gallery) to both shapes — read/write on `me`, read-only on `public`. Validation for the
structured JSON fields enforces type + key shape so the partner-app's CRUD UI can't poison the DB
with malformed dicts that would crash buyer-side rendering.
"""
from rest_framework import serializers

from .models import QassobPhoto, QassobProfile, VALID_ANIMAL_CODES


# ---- shared field validators ----

def _validate_animal_codes(value):
    """Common validator for animals_supported lists. Raises if any code is unknown."""
    if not isinstance(value, list):
        raise serializers.ValidationError("Must be a list of animal codes.")
    bad = [c for c in value if c not in VALID_ANIMAL_CODES]
    if bad:
        raise serializers.ValidationError(
            f"Unknown animal codes: {bad}. Allowed: {sorted(VALID_ANIMAL_CODES)}.")
    return value


_WEEKDAYS = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"}
_LANG_CODES = {"uz", "ru", "en", "tg"}


def _validate_specialties(value):
    """List of short non-empty strings; cap at 12 chips so the buyer card row doesn't run forever."""
    if not isinstance(value, list):
        raise serializers.ValidationError("Must be a list of strings.")
    if len(value) > 12:
        raise serializers.ValidationError("Maximum 12 specialties.")
    for v in value:
        if not isinstance(v, str) or not v.strip():
            raise serializers.ValidationError("Each specialty must be a non-empty string.")
        if len(v) > 60:
            raise serializers.ValidationError(f"Specialty too long (>60 chars): {v[:30]}…")
    return [v.strip() for v in value]


def _validate_certifications(value):
    """List of {name: str, year: int?} dicts."""
    if not isinstance(value, list):
        raise serializers.ValidationError("Must be a list of certification dicts.")
    if len(value) > 20:
        raise serializers.ValidationError("Maximum 20 certifications.")
    cleaned = []
    for row in value:
        if not isinstance(row, dict) or "name" not in row:
            raise serializers.ValidationError("Each row must be a dict with at least a 'name' key.")
        name = str(row["name"]).strip()
        if not name:
            raise serializers.ValidationError("Certification name cannot be empty.")
        year = row.get("year")
        if year is not None:
            try:
                year = int(year)
            except (TypeError, ValueError):
                raise serializers.ValidationError(f"Year must be an integer or null (got {year!r}).")
            if year < 1950 or year > 2100:
                raise serializers.ValidationError(f"Year out of range: {year}")
        cleaned.append({"name": name, "year": year})
    return cleaned


def _validate_working_hours(value):
    """Dict of weekday → [open_h, close_h] (ints 0-23, open<close) OR null=closed."""
    if not isinstance(value, dict):
        raise serializers.ValidationError("Must be a dict keyed by weekday code (mon..sun).")
    cleaned = {}
    for day, hours in value.items():
        if day not in _WEEKDAYS:
            raise serializers.ValidationError(f"Unknown weekday code: {day}. Allowed: {sorted(_WEEKDAYS)}.")
        if hours is None:
            cleaned[day] = None
            continue
        if not (isinstance(hours, list) and len(hours) == 2):
            raise serializers.ValidationError(f"{day}: must be [open_h, close_h] or null.")
        try:
            o, c = int(hours[0]), int(hours[1])
        except (TypeError, ValueError):
            raise serializers.ValidationError(f"{day}: hours must be integers.")
        if not (0 <= o < c <= 24):
            raise serializers.ValidationError(f"{day}: need 0 <= open < close <= 24 (got {o}, {c}).")
        cleaned[day] = [o, c]
    return cleaned


def _validate_price_list(value):
    """List of {service: str, price_uzs: int, unit: str} dicts."""
    if not isinstance(value, list):
        raise serializers.ValidationError("Must be a list of price-row dicts.")
    if len(value) > 50:
        raise serializers.ValidationError("Maximum 50 price rows.")
    cleaned = []
    for row in value:
        if not isinstance(row, dict):
            raise serializers.ValidationError("Each row must be a dict.")
        for k in ("service", "price_uzs", "unit"):
            if k not in row:
                raise serializers.ValidationError(f"Missing key '{k}' in price row.")
        service = str(row["service"]).strip()
        unit = str(row["unit"]).strip()
        if not service: raise serializers.ValidationError("service cannot be empty.")
        if not unit: raise serializers.ValidationError("unit cannot be empty.")
        try:
            price = int(row["price_uzs"])
        except (TypeError, ValueError):
            raise serializers.ValidationError(f"price_uzs must be an integer (got {row['price_uzs']!r}).")
        if price < 0:
            raise serializers.ValidationError("price_uzs cannot be negative.")
        cleaned.append({"service": service, "price_uzs": price, "unit": unit})
    return cleaned


def _validate_languages(value):
    """List of ISO codes from _LANG_CODES."""
    if not isinstance(value, list):
        raise serializers.ValidationError("Must be a list of language codes.")
    cleaned = []
    seen = set()
    for v in value:
        code = str(v).strip().lower()
        if code not in _LANG_CODES:
            raise serializers.ValidationError(f"Unknown language code: {code}. Allowed: {sorted(_LANG_CODES)}.")
        if code in seen: continue                                     # dedupe silently
        seen.add(code); cleaned.append(code)
    return cleaned


class QassobPhotoSerializer(serializers.ModelSerializer):
    """Gallery photo shape — used both as a nested read on the parent serializers and as the direct
    write surface on POST /qassobs/me/photos/ (multipart upload)."""

    image_url = serializers.SerializerMethodField()

    class Meta:
        model = QassobPhoto
        fields = ("id", "image", "image_url", "caption", "position", "created_at")
        read_only_fields = ("id", "image_url", "created_at")
        extra_kwargs = {"image": {"write_only": True}}

    def get_image_url(self, obj):
        if not obj.image: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.image.url) if req else obj.image.url


class QassobMeSerializer(serializers.ModelSerializer):
    """Owner-side CRUD shape. PATCH from the partner-app Profile / Servisim screen lands here.
    `is_verified` is read-only — only admin flips it from Django Admin after KYC review.

    v3.9: surfaces the 7 service-profile fields + nested gallery photos for the partner-app Servisim
    CRUD UI. Gallery is read-only here (writes go through the dedicated /qassobs/me/photos/ endpoint
    because multipart + nested writes don't compose cleanly in DRF)."""

    photo_url = serializers.SerializerMethodField()
    email = serializers.EmailField(source="user.email", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)
    gallery = QassobPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = QassobProfile
        fields = ("id", "email", "phone",
                  "full_name", "years_experience",
                  "region", "address", "lat", "lng", "service_radius_km",
                  "animals_supported", "is_slaughterhouse", "daily_capacity_head",
                  "photo", "photo_url",
                  "phone_visible", "telegram_username",
                  "is_open_now", "rating_avg", "rating_count", "is_verified",
                  # v3.9 service profile
                  "bio", "specialties", "certifications", "working_hours",
                  "price_list", "languages", "gallery",
                  "created_at", "updated_at")
        read_only_fields = ("id", "email", "phone", "rating_avg", "rating_count",
                            "is_verified", "photo_url", "gallery", "created_at", "updated_at")

    def get_photo_url(self, obj):
        if not obj.photo: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.photo.url) if req else obj.photo.url

    # Validation hooks — DRF auto-dispatches `validate_<field>` for each JSONField, keeping the
    # per-field logic adjacent to the field declaration.
    def validate_animals_supported(self, v): return _validate_animal_codes(v)
    def validate_specialties(self, v): return _validate_specialties(v)
    def validate_certifications(self, v): return _validate_certifications(v)
    def validate_working_hours(self, v): return _validate_working_hours(v)
    def validate_price_list(self, v): return _validate_price_list(v)
    def validate_languages(self, v): return _validate_languages(v)


class QassobPublicSerializer(serializers.ModelSerializer):
    """Buyer-app Servislar tab + detail. Hides admin/internal fields. Phone only included when
    `phone_visible` is True. Computes `distance_km` when the request supplies buyer lat/lng query
    params. v3.9 also surfaces the 7 service-profile fields so the buyer's qassob detail page can
    render bio / specialties / certifications / working_hours / price_list / languages / gallery in
    one round-trip."""

    photo_url = serializers.SerializerMethodField()
    phone = serializers.SerializerMethodField()
    telegram = serializers.CharField(source="telegram_username", read_only=True)
    distance_km = serializers.SerializerMethodField()
    gallery = QassobPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = QassobProfile
        fields = ("id", "full_name", "years_experience",
                  "region", "address", "lat", "lng", "service_radius_km",
                  "animals_supported", "is_slaughterhouse",
                  "photo_url", "phone", "telegram",
                  "is_open_now", "rating_avg", "rating_count", "distance_km",
                  # v3.9 service profile fields
                  "bio", "specialties", "certifications", "working_hours",
                  "price_list", "languages", "gallery")
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
