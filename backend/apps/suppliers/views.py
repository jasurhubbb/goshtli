"""Supplier views — /me for profile read/update, /dashboard for the supplier home screen aggregate."""
from django.db.models import Count, Q
from drf_spectacular.utils import extend_schema
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsSupplier
from apps.listings.models import Listing
from apps.orders.models import Order
from .models import SupplierProfile
from .serializers import SupplierDashboardSerializer, SupplierProfileSerializer


class SupplierMeView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/v1/suppliers/me/ — current supplier's profile. Auto-created via signal at registration."""
    serializer_class = SupplierProfileSerializer
    permission_classes = (IsSupplier,)
    http_method_names = ("get", "patch", "head", "options")

    def get_object(self):
        # get_or_create handles the rare case the signal didn't run (e.g. shell-created users); keeps /me always 200
        profile, _ = SupplierProfile.objects.get_or_create(user=self.request.user, defaults={"business_name": ""})
        return profile


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
            sold_out=Count("id", filter=Q(status=Listing.Status.SOLD_OUT)),
            inactive=Count("id", filter=Q(status=Listing.Status.INACTIVE)))
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
