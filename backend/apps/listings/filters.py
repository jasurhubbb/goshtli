"""django-filter spec for the public listing browse endpoint.

v3.1 catalog overhaul: filters now align with the new schema.
  • category — buyer picks "Mol go'shti" tile → ?category=mol-goshti (slug-based for clean URLs)
  • market — single-market view → ?market=osh-bozor (also slug-based)
  • region — derived from market.region for "near me" filter → ?region=Toshkent
  • status — buyers normally see only ACTIVE; admin tooling can pass ?status=OUT_OF_STOCK explicitly
  • price_min / price_max — range filter via numeric query params
  • q — full-text-ish search on name_uz + name_ru (icontains for now; promote to Postgres FTS later)

Removed filters (no longer in schema): halal_certified, cold_chain, service_area, meat_type.
The legacy `verified_only` filter is gone too — verification moved off the supplier_profile in the v3 pivot.
"""
from django_filters import rest_framework as filters
from django.db.models import Q

from .models import Listing


class ListingFilter(filters.FilterSet):
    # Range filters use suffixed lookups so callers send ?price_min=... &price_max=... instead of a query DSL
    price_min = filters.NumberFilter(field_name="price_per_kg", lookup_expr="gte")
    price_max = filters.NumberFilter(field_name="price_per_kg", lookup_expr="lte")

    # Slug-based FK filters — easier on URLs than numeric IDs ("?category=mol-goshti" not "?category=3")
    category = filters.CharFilter(field_name="category__slug", lookup_expr="exact")
    market = filters.CharFilter(field_name="market__slug", lookup_expr="exact")
    region = filters.CharFilter(field_name="market__region", lookup_expr="iexact")

    # Free-text search across bilingual name fields. icontains is good for v1; switch to Postgres SearchVector
    # when catalog size or latency demand it.
    q = filters.CharFilter(method="filter_text_search", label="Search query")

    # v3.6 live-animal facets per PRD §2: lets the buyer toggle between raw-meat and live-animal sub-catalogs,
    # then narrow by breed. The home grid surfaces this as a top-of-screen segmented control.
    is_live_animal = filters.BooleanFilter(field_name="is_live_animal")
    breed = filters.CharFilter(field_name="breed_type", lookup_expr="iexact")

    def filter_text_search(self, queryset, name, value):
        """Match query against both name_uz and name_ru — buyers searching in either language hit results."""
        if not value:
            return queryset
        return queryset.filter(Q(name_uz__icontains=value) | Q(name_ru__icontains=value))

    class Meta:
        model = Listing
        fields = ("category", "market", "region", "status", "price_min", "price_max", "q",
                  "is_live_animal", "breed")
