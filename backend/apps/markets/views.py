"""Market views — read for everyone (browse + listing-form pickers), write for admins only.

The Market model + admin interface have existed since v3.1; this file just adds the REST surface the mobile
admin page needs to pick a market when creating a listing, and to CRUD markets in the Boshqarish tab.
"""
from django.utils.text import slugify
from rest_framework import generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView

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


class MyMarketView(APIView):
    """GET /api/v1/markets/me/ — current authenticated user's owned Market. Auto-creates one if missing.

    v3.8.2: partner-app suppliers sign up via the wizard and need a Market to attach listings to. Without
    this, the Yangi tovar form's market picker defaulted to `markets.first` which was Asad ota's admin-
    created market, so every partner's listing ended up under Asad ota's shopfront. This endpoint creates
    a 1:1 Market for the supplier on first call, named after their full_name (with slug collision
    handling), and returns it. Subsequent calls return the same row.
    """
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        user = request.user
        market = getattr(user, "owned_market", None)
        if market is None:
            base_name = (user.full_name or f"Bozor #{user.pk}").strip()
            base_slug = slugify(base_name)[:80] or f"market-{user.pk}"
            slug = base_slug
            i = 0
            while Market.objects.filter(slug=slug).exists():
                i += 1
                slug = f"{base_slug}-{i}"
            market = Market.objects.create(
                owner_user=user, slug=slug,
                name_uz=base_name, name_ru=base_name,
                address="", region="Toshkent")
        return Response(MarketSerializer(market, context={"request": request}).data)
