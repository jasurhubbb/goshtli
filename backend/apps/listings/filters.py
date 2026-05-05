"""django-filter spec for the public listing browse endpoint — meat_type, location, status, price range."""
from django_filters import rest_framework as filters
from .models import Listing


class ListingFilter(filters.FilterSet):
    # Range filters use suffixed lookups so callers send ?price_min=... &price_max=... instead of query DSL strings
    price_min = filters.NumberFilter(field_name="price_per_kg", lookup_expr="gte")
    price_max = filters.NumberFilter(field_name="price_per_kg", lookup_expr="lte")
    location = filters.CharFilter(field_name="location", lookup_expr="icontains")  # case-insensitive partial match

    class Meta:
        model = Listing
        fields = ("meat_type", "status", "location", "price_min", "price_max")
