"""Listing views — public browse for buyers, owner-scoped CRUD for suppliers, plus a /my/ shortcut."""
from rest_framework import generics, permissions
from rest_framework.exceptions import PermissionDenied

from apps.common.permissions import IsListingOwnerOrReadOnly, IsVerifiedSupplier
from .filters import ListingFilter
from .models import Listing
from .serializers import ListingSerializer


class ListingListCreateView(generics.ListCreateAPIView):
    """GET (public, only ACTIVE) + POST (verified-supplier) on /api/v1/listings/."""
    serializer_class = ListingSerializer
    filterset_class = ListingFilter
    search_fields = ("title", "description")            # ?search=... powered by DRF SearchFilter
    ordering_fields = ("price_per_kg", "available_from", "created_at")  # ?ordering=price_per_kg
    ordering = ("-created_at",)

    def get_queryset(self):
        # Public browse hides INACTIVE/SOLD_OUT by default unless caller explicitly filters by status
        qs = Listing.objects.select_related("supplier", "supplier__supplier_profile")
        if self.request.method in ("GET", "HEAD") and "status" not in self.request.query_params:
            qs = qs.filter(status=Listing.Status.ACTIVE)
        return qs

    def get_permissions(self):
        # Anyone can browse; only verified suppliers can post — matches the workflow spec
        if self.request.method in permissions.SAFE_METHODS: return [permissions.AllowAny()]
        return [IsVerifiedSupplier()]

    def perform_create(self, serializer):
        # supplier is taken from the authenticated user — never trust client input for ownership fields
        serializer.save(supplier=self.request.user, status=Listing.Status.ACTIVE)


class ListingDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /api/v1/listings/{id}/ — buyers read public listings; suppliers manage only their own."""
    serializer_class = ListingSerializer
    queryset = Listing.objects.select_related("supplier", "supplier__supplier_profile")
    permission_classes = (permissions.IsAuthenticatedOrReadOnly, IsListingOwnerOrReadOnly)

    def perform_destroy(self, instance):
        # Refuse deletion if there are orders attached — preserves audit trail; supplier should INACTIVATE instead
        if instance.orders.exists():
            raise PermissionDenied("Cannot delete a listing that has orders. Set status to INACTIVE instead.")
        instance.delete()


class MyListingsView(generics.ListAPIView):
    """GET /api/v1/listings/my/ — convenience view for the supplier dashboard (all statuses, owner-only)."""
    serializer_class = ListingSerializer
    permission_classes = (IsVerifiedSupplier,)
    filterset_class = ListingFilter
    ordering = ("-created_at",)

    def get_queryset(self):
        # During schema generation request.user is anonymous; return an empty qs so spectacular can introspect the model.
        if getattr(self, "swagger_fake_view", False): return Listing.objects.none()
        return Listing.objects.filter(supplier=self.request.user)
