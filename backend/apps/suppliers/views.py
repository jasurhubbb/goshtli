"""Supplier views — /me for profile read/update, /dashboard for the supplier home screen aggregate.
v3.3 adds /list/ (admin-curated supplier picker) and /<id>/ (admin edit of any supplier profile)."""
from django.db.models import Count, Q
from drf_spectacular.utils import extend_schema
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from rest_framework import parsers as drf_parsers

from apps.common.permissions import IsAdminRole, IsSupplier
from apps.listings.models import Listing
from apps.orders.models import Order
from .models import SupplierProfile
from .serializers import SupplierDashboardSerializer, SupplierProfileSerializer


class SupplierMeView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/v1/suppliers/me/ — current supplier's profile. Auto-created via signal at registration.

    Accepts both JSON and multipart/form-data so the partner-app profile-edit page can PATCH the
    avatar file in the same request as the rest of the structured fields (v3.9.10).
    """
    serializer_class = SupplierProfileSerializer
    permission_classes = (IsSupplier,)
    parser_classes = (drf_parsers.JSONParser, drf_parsers.MultiPartParser, drf_parsers.FormParser)
    http_method_names = ("get", "patch", "head", "options")

    def get_object(self):
        # get_or_create handles the rare case the signal didn't run (e.g. shell-created users); keeps /me always 200
        profile, _ = SupplierProfile.objects.get_or_create(user=self.request.user, defaults={"business_name": ""})
        return profile


class SupplierListView(generics.ListAPIView):
    """GET /api/v1/suppliers/list/ — admin-only; returns every SupplierProfile so the in-app admin picker can show
    real suppliers when assigning a listing to one. Verified flag is included so the picker can mark non-verified
    suppliers (admin still creates listings for them, but the UI hints at the verification state)."""
    serializer_class = SupplierProfileSerializer
    permission_classes = (IsAdminRole,)
    queryset = SupplierProfile.objects.select_related("user").order_by("business_name", "user__full_name")


class SupplierAdminDetailView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/v1/suppliers/<pk>/ — admin edits any supplier's profile (business_name/region/address). Verification
    flag is writeable here because the in-app admin needs to flip it; SupplierMeView keeps it read-only for self-edit."""
    serializer_class = SupplierProfileSerializer
    permission_classes = (IsAdminRole,)
    queryset = SupplierProfile.objects.select_related("user")
    http_method_names = ("get", "patch", "head", "options")

    def get_serializer_class(self):
        # Admin path — drop is_verified from read_only_fields so admin can toggle it. Local subclass keeps the
        # change scoped to this view; SupplierMeView still gets the verified-locked serializer.
        Base = SupplierProfileSerializer
        class _AdminSerializer(Base):
            class Meta(Base.Meta):
                read_only_fields = ("id", "created_at", "updated_at")  # is_verified writable for admin
        return _AdminSerializer


@extend_schema(responses={200: SupplierDashboardSerializer},
               description="Aggregated supplier home metrics — listings counts by status + orders counts by status, in one query.")
class SupplierDashboardView(APIView):
    """GET /api/v1/suppliers/dashboard/ — single-roundtrip aggregate so the mobile home screen never N+1s."""
    permission_classes = (IsSupplier,)

    def get(self, request):
        u = request.user
        # Listing counts grouped by status — one query with conditional aggregation
        l_agg = Listing.objects.filter(supplier=u).aggregate(
            total=Count("id"),
            active=Count("id", filter=Q(status=Listing.Status.ACTIVE)),
            sold_out=Count("id", filter=Q(status=Listing.Status.OUT_OF_STOCK)),
            inactive=Count("id", filter=Q(status=Listing.Status.ARCHIVED)))
        # Order counts on this supplier's listings — collapse the in-progress states into one bucket for UI simplicity
        IN_PROGRESS = (Order.Status.CONFIRMED, Order.Status.PROCESSING, Order.Status.IN_TRANSIT)
        o_agg = Order.objects.filter(listing__supplier=u).aggregate(
            pending=Count("id", filter=Q(status=Order.Status.PENDING)),
            in_progress=Count("id", filter=Q(status__in=IN_PROGRESS)),
            delivered=Count("id", filter=Q(status=Order.Status.DELIVERED)),
            cancelled=Count("id", filter=Q(status=Order.Status.CANCELLED)))
        data = {"is_verified": getattr(getattr(u, "supplier_profile", None), "is_verified", False),
                "listings_total": l_agg["total"], "listings_active": l_agg["active"],
                "listings_sold_out": l_agg["sold_out"], "listings_inactive": l_agg["inactive"],
                "orders_pending": o_agg["pending"], "orders_in_progress": o_agg["in_progress"],
                "orders_delivered": o_agg["delivered"], "orders_cancelled": o_agg["cancelled"]}
        return Response(SupplierDashboardSerializer(data).data)
