"""Supplier serializers — profile shape returned by /suppliers/me/, plus the dashboard aggregate."""
from rest_framework import serializers
from .models import SupplierProfile


class SupplierProfileSerializer(serializers.ModelSerializer):
    """Public-safe profile representation. is_verified is read-only — only admin can change it (via Django Admin).

    v3.8.2: animals_supported is exposed read/write so the partner-app can (a) filter the new-listing
    category chips down to what this supplier actually sells, and (b) let them edit the list later from
    the Profile tab without going back through the onboarding wizard.

    v3.9.10: also exposes photo (write) + photo_url (read) so suppliers can set + display an avatar
    on the partner-app Profil tab, matching the qassob flow. Without this, an uploaded shopfront
    photo landed in the DB but no client could ever see it.
    """
    email = serializers.EmailField(source="user.email", read_only=True)
    full_name = serializers.CharField(source="user.full_name", read_only=True)
    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = SupplierProfile
        fields = ("id", "email", "full_name", "business_name", "region", "address",
                  "animals_supported", "photo", "photo_url",
                  "is_verified", "created_at", "updated_at")
        read_only_fields = ("id", "photo_url", "is_verified", "created_at", "updated_at")
        extra_kwargs = {"photo": {"write_only": True, "required": False}}

    def get_photo_url(self, obj):
        if not obj.photo: return ""
        req = self.context.get("request")
        return req.build_absolute_uri(obj.photo.url) if req else obj.photo.url


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
