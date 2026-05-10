"""django-filter spec for the public listing browse endpoint.

v2 adds: halal_certified (boolean toggle), cold_chain (FRESH/CHILLED/FROZEN), service_area (icontains over CSV),
verified_only (filter to supplier_profile.is_verified=True listings).
"""
from django_filters import rest_framework as filters
from .models import Listing


class ListingFilter(filters.FilterSet):
    # Range filters use suffixed lookups so callers send ?price_min=... &price_max=... instead of query DSL strings
    price_min = filters.NumberFilter(field_name="price_per_kg", lookup_expr="gte")
    price_max = filters.NumberFilter(field_name="price_per_kg", lookup_expr="lte")
    # Case-insensitive partial match — buyer types "tashk" and matches both Tashkent + Toshkent
    location = filters.CharFilter(field_name="location", lookup_expr="icontains")
    # v2: service area is a comma-separated CSV; icontains over the whole string is good-enough for ≤ 20 regions per supplier
    service_area = filters.CharFilter(field_name="service_area_csv", lookup_expr="icontains")
    # v2: filter to verified suppliers only — frontends use this for the "trusted sellers" toggle
    verified_only = filters.BooleanFilter(field_name="supplier__supplier_profile__is_verified")

    class Meta:
        model = Listing
        # halal_certified + cold_chain are simple equality filters — django-filter auto-handles those from Meta.fields
        fields = ("meat_type", "status", "location", "price_min", "price_max",
                  "halal_certified", "cold_chain", "service_area", "verified_only")
