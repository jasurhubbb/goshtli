"""Listing views — public browse, owner-scoped CRUD, plus the v2 photo upload + delete endpoints.
v3.3: admin role bypasses owner / verification checks (see common.permissions) and may set supplier_id on create."""
from django.contrib.auth import get_user_model
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsAdminRole, IsListingOwnerOrReadOnly, IsVerifiedSupplier
from .filters import ListingFilter
from .models import Listing, ListingPhoto, MeatCategory
from .serializers import ListingPhotoSerializer, ListingSerializer, MeatCategorySerializer

User = get_user_model()


class MeatCategoryListCreateView(generics.ListCreateAPIView):
    """GET /api/v1/categories/  — public; only active categories sorted by display_order
    POST /api/v1/categories/  — admin-only; new category for the home grid"""
    serializer_class = MeatCategorySerializer

    def get_queryset(self):
        qs = MeatCategory.objects.all()
        if self.request.method in permissions.SAFE_METHODS and self.request.query_params.get("include_inactive") != "1":
            qs = qs.filter(is_active=True)
        return qs.order_by("display_order", "name_uz")

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS: return [permissions.AllowAny()]
        return [IsAdminRole()]


class MeatCategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET (public) / PATCH (admin) / DELETE (admin, soft-archive) /api/v1/categories/<pk>/."""
    serializer_class = MeatCategorySerializer
    queryset = MeatCategory.objects.all()
    http_method_names = ("get", "patch", "delete", "head", "options")

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS: return [permissions.AllowAny()]
        return [IsAdminRole()]

    def perform_destroy(self, instance):
        # Soft-delete preserves listings.category FK so existing rows don't break. Hard-delete = Django Admin only.
        instance.is_active = False
        instance.save(update_fields=["is_active", "updated_at"])


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
            # v3.3: ADMIN users skip the ACTIVE-only default — the in-app admin "E'lonlar" tab needs to see
            # every listing including ARCHIVED + OUT_OF_STOCK to manage them. Buyers/anonymous still get only ACTIVE.
            u = self.request.user
            if not (u.is_authenticated and u.is_admin_role):
                qs = qs.filter(status=Listing.Status.ACTIVE)
        return qs

    def get_permissions(self):
        # Anyone can browse; only VERIFIED suppliers can post. v2 verification gate stays.
        if self.request.method in permissions.SAFE_METHODS: return [permissions.AllowAny()]
        return [IsVerifiedSupplier()]

    def perform_create(self, serializer):
        # Default: supplier = authenticated user (a verified supplier creating their own listing).
        # v3.3 admin paths (in-app admin treats Bozor = supplier as one concept):
        #   1. Caller passes supplier_id → resolve to that User (explicit override; legacy contract)
        #   2. Caller passes only market_id → resolve to the Market's backing owner_user (preferred — admin
        #      picks a Market in the UI and the backend transparently maps it to a User)
        # If neither path yields a supplier we raise; admins MUST tie a listing to a Market via owner_user.
        supplier = self.request.user
        if self.request.user.is_admin_role:
            sup_id = self.request.data.get("supplier_id")
            if sup_id is not None:
                try:
                    supplier = User.objects.get(pk=int(sup_id))
                except (User.DoesNotExist, ValueError, TypeError):
                    raise ValidationError({"supplier_id": "Unknown supplier."})
            else:
                # Resolve supplier from the validated market's owner_user — set during MarketSerializer.create()
                market = serializer.validated_data.get("market")
                if market is None or market.owner_user_id is None:
                    raise ValidationError({"market_id": "This market has no backing supplier user. Recreate it."})
                supplier = market.owner_user
        # _actor is a non-field attribute consumed by the price-history signal on subsequent updates (not used on
        # create — the signal short-circuits when created=True).
        serializer.save(supplier=supplier, created_by=self.request.user, status=Listing.Status.ACTIVE)

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
        # v3.9.13 — split the "has orders" gate into two cases so the supplier's partner-app CAN
        # delete listings that only have terminal (DELIVERED / CANCELLED) orders in history:
        #
        #   1. Any NON-terminal order → 400, "buyurtmalar tugatilishi kerak" (finish them first).
        #      That's the user's product requirement: no destroying a listing mid-fulfillment.
        #   2. Only terminal orders → soft-delete via status=ARCHIVED (buyer stops seeing it, but
        #      the historical Order rows keep their FK).
        #   3. Zero orders at all → hard delete.
        from apps.orders.models import Order
        NON_TERMINAL = (Order.Status.PENDING, Order.Status.CONFIRMED, Order.Status.PROCESSING,
                        Order.Status.PROCESSING_BUTCHER, Order.Status.AWAITING_QASSOB,
                        Order.Status.IN_TRANSIT)
        active = instance.orders.filter(status__in=NON_TERMINAL).count()
        if active > 0:
            raise PermissionDenied(
                f"Bu tovarda {active} ta aktiv buyurtma bor. Avval hammasini yakunlang.")
        if instance.orders.exists():
            instance.status = Listing.Status.ARCHIVED
            instance.save(update_fields=("status", "updated_at"))
        else:
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
        # v3.3 admin bypass: ADMIN-role users can attach photos to any listing (they own all listings conceptually).
        if listing.supplier_id != request.user.id and not request.user.is_admin_role:
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
        # v3.3 admin bypass — see ListingPhotoUploadView.post.
        if photo.listing.supplier_id != request.user.id and not request.user.is_admin_role:
            raise PermissionDenied("You don't own this listing.")
        # Delete the file from storage before the DB row so we never leak orphaned files on partial failure
        photo.image.delete(save=False)
        photo.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
