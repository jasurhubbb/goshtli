"""Market views — read for everyone (browse + listing-form pickers), write for admins only.

The Market model + admin interface have existed since v3.1; this file just adds the REST surface the mobile
admin page needs to pick a market when creating a listing, and to CRUD markets in the Boshqarish tab.
"""
from rest_framework import generics, permissions

from apps.common.permissions import IsAdminRole
from .models import Market
from .serializers import MarketSerializer


class MarketListCreateView(generics.ListCreateAPIView):
    """GET /api/v1/markets/  — public list (active markets only, for the buyer + listing-form picker)
    POST /api/v1/markets/   — admin-only; creates a market row. slug auto-derives from name_uz on save()."""
    serializer_class = MarketSerializer

    def get_queryset(self):
        qs = Market.objects.all()
        # Public reads hide is_active=False; admin can opt in via ?include_inactive=1 query param
        if self.request.method in permissions.SAFE_METHODS and self.request.query_params.get("include_inactive") != "1":
            qs = qs.filter(is_active=True)
        return qs.order_by("name_uz")

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS: return [permissions.AllowAny()]
        return [IsAdminRole()]

    def perform_create(self, serializer):
        # created_by stamps which admin curated this row — visible in Django Admin's history view
        serializer.save(created_by=self.request.user, updated_by=self.request.user)


class MarketDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET /api/v1/markets/<pk>/   — public read
    PATCH/DELETE /api/v1/markets/<pk>/ — admin-only; DELETE soft-archives by flipping is_active=False so
    historical orders that reference this market keep their FK intact."""
    serializer_class = MarketSerializer
    queryset = Market.objects.all()
    http_method_names = ("get", "patch", "delete", "head", "options")

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS: return [permissions.AllowAny()]
        return [IsAdminRole()]

    def perform_update(self, serializer):
        serializer.save(updated_by=self.request.user)

    def perform_destroy(self, instance):
        # Soft-delete — preserves listings/orders FK. Real deletes go through Django Admin if absolutely needed.
        instance.is_active = False
        instance.save(update_fields=["is_active", "updated_at"])
