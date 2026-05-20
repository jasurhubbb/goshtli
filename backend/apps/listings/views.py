"""Listing views — public browse, owner-scoped CRUD, plus the v2 photo upload + delete endpoints."""
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsListingOwnerOrReadOnly, IsVerifiedSupplier
from .filters import ListingFilter
from .models import Listing, ListingPhoto
from .serializers import ListingPhotoSerializer, ListingSerializer


class ListingListCreateView(generics.ListCreateAPIView):
    """GET (public, only ACTIVE) + POST (verified-supplier) on /api/v1/listings/."""
    serializer_class = ListingSerializer
    filterset_class = ListingFilter
    # Search across bilingual name + description fields so buyers find products in either Uzbek or Russian
    search_fields = ("name_uz", "name_ru", "description_uz", "description_ru", "location")
    ordering_fields = ("price_per_kg", "available_from", "created_at")
    ordering = ("-created_at",)

    def get_queryset(self):
        # Public browse hides ARCHIVED/OUT_OF_STOCK by default. select_related the FKs so each card render is
        # 1 query, not N+1; prefetch photos for the same reason.
        qs = (Listing.objects
              .select_related("supplier", "market", "category")
              .prefetch_related("photos"))
        if self.request.method in ("GET", "HEAD") and "status" not in self.request.query_params:
            qs = qs.filter(status=Listing.Status.ACTIVE)
        return qs

    def get_permissions(self):
        # Anyone can browse; only VERIFIED suppliers can post. v2 verification gate stays.
        if self.request.method in permissions.SAFE_METHODS: return [permissions.AllowAny()]
        return [IsVerifiedSupplier()]

    def perform_create(self, serializer):
        # supplier always taken from authenticated user — never trust client input for ownership.
        # created_by stamps who made the row; _actor is a non-field attribute consumed by the price-history signal
        # on subsequent updates (not used on create — the signal short-circuits when created=True).
        serializer.save(supplier=self.request.user, created_by=self.request.user, status=Listing.Status.ACTIVE)

    def perform_update(self, serializer):
        # Set _actor on the existing instance BEFORE save() fires the signal. _actor is not a model field, so it
        # can't be passed through serializer.save() kwargs — assign it directly to the instance object.
        if serializer.instance is not None:
            serializer.instance._actor = self.request.user
        serializer.save(updated_by=self.request.user)


class ListingDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /api/v1/listings/{id}/ — buyers read public listings; owner manages their own."""
    serializer_class = ListingSerializer
    queryset = (Listing.objects
                .select_related("supplier", "market", "category")
                .prefetch_related("photos"))
    permission_classes = (permissions.IsAuthenticatedOrReadOnly, IsListingOwnerOrReadOnly)

    def perform_destroy(self, instance):
        # Refuse hard-delete if there are orders attached — preserves FK integrity. Set status=ARCHIVED for soft delete.
        if instance.orders.exists():
            raise PermissionDenied("Cannot delete a listing that has orders. Set status to ARCHIVED instead.")
        instance.delete()


class MyListingsView(generics.ListAPIView):
    """GET /api/v1/listings/my/ — owner's listings, all statuses, includes photos."""
    serializer_class = ListingSerializer
    permission_classes = (IsVerifiedSupplier,)
    filterset_class = ListingFilter
    ordering = ("-created_at",)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Listing.objects.none()
        return (Listing.objects.filter(supplier=self.request.user)
                .select_related("market", "category").prefetch_related("photos"))


# ---------- Photo upload + delete (v2) ----------

@extend_schema(request={"multipart/form-data": {"type": "object",
                                                "properties": {"image": {"type": "string", "format": "binary"}}}},
               responses={201: ListingPhotoSerializer},
               parameters=[OpenApiParameter("listing_pk", OpenApiTypes.INT, OpenApiParameter.PATH)])
class ListingPhotoUploadView(APIView):
    """POST /api/v1/listings/{listing_pk}/photos/ — owner-only. Multipart form with 'image' file. Returns the photo row.

    First uploaded photo gets position=0 (= primary thumbnail); subsequent uploads auto-increment so card thumbs stay stable.
    """
    permission_classes = (permissions.IsAuthenticated,)
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, listing_pk):
        try: listing = Listing.objects.get(pk=listing_pk)
        except Listing.DoesNotExist: raise NotFound()
        if listing.supplier_id != request.user.id:
            raise PermissionDenied("You don't own this listing.")
        if "image" not in request.FILES:
            return Response({"image": ["This field is required."]}, status=status.HTTP_400_BAD_REQUEST)

        # Determine next position so the upload order matches the gallery order on the mobile side
        next_pos = (listing.photos.order_by("-position").values_list("position", flat=True).first() or -1) + 1
        photo = ListingPhoto.objects.create(listing=listing, image=request.FILES["image"], position=next_pos)
        return Response(ListingPhotoSerializer(photo, context={"request": request}).data,
                        status=status.HTTP_201_CREATED)


@extend_schema(parameters=[OpenApiParameter("listing_pk", OpenApiTypes.INT, OpenApiParameter.PATH),
                           OpenApiParameter("pk", OpenApiTypes.INT, OpenApiParameter.PATH)])
class ListingPhotoDeleteView(APIView):
    """DELETE /api/v1/listings/{listing_pk}/photos/{pk}/ — owner-only. Removes the file + DB row."""
    permission_classes = (permissions.IsAuthenticated,)

    def delete(self, request, listing_pk, pk):
        try: photo = ListingPhoto.objects.select_related("listing").get(pk=pk, listing_id=listing_pk)
        except ListingPhoto.DoesNotExist: raise NotFound()
        if photo.listing.supplier_id != request.user.id:
            raise PermissionDenied("You don't own this listing.")
        # Delete the file from storage before the DB row so we never leak orphaned files on partial failure
        photo.image.delete(save=False)
        photo.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
