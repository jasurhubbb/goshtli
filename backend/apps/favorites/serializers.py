"""Favorite serializer — embeds the full Listing so the saved-listings screen renders in one round-trip."""
from rest_framework import serializers

from apps.listings.serializers import ListingSerializer
from .models import Favorite


class FavoriteSerializer(serializers.ModelSerializer):
    listing = ListingSerializer(read_only=True)

    class Meta:
        model = Favorite
        fields = ("id", "listing", "created_at")
        read_only_fields = fields
