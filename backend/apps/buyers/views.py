"""Buyer views — /me profile and /dashboard order summary."""
from django.db.models import Count, Q
from drf_spectacular.utils import extend_schema
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsBuyer
from apps.orders.models import Order
from .models import BuyerProfile
from .serializers import BuyerDashboardSerializer, BuyerProfileSerializer


class BuyerMeView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/v1/buyers/me/ — current buyer's profile. Auto-created via signal."""
    serializer_class = BuyerProfileSerializer
    permission_classes = (IsBuyer,)
    http_method_names = ("get", "patch", "head", "options")

    def get_object(self):
        profile, _ = BuyerProfile.objects.get_or_create(user=self.request.user)
        return profile


@extend_schema(responses={200: BuyerDashboardSerializer},
               description="Aggregated buyer home metrics — order counts grouped by status.")
class BuyerDashboardView(APIView):
    """GET /api/v1/buyers/dashboard/ — single aggregated counts response."""
    permission_classes = (IsBuyer,)

    def get(self, request):
        IN_PROGRESS = (Order.Status.CONFIRMED, Order.Status.PROCESSING, Order.Status.IN_TRANSIT)
        agg = Order.objects.filter(buyer=request.user).aggregate(
            pending=Count("id", filter=Q(status=Order.Status.PENDING)),
            in_progress=Count("id", filter=Q(status__in=IN_PROGRESS)),
            delivered=Count("id", filter=Q(status=Order.Status.DELIVERED)),
            cancelled=Count("id", filter=Q(status=Order.Status.CANCELLED)))
        return Response(BuyerDashboardSerializer({
            "orders_pending": agg["pending"], "orders_in_progress": agg["in_progress"],
            "orders_delivered": agg["delivered"], "orders_cancelled": agg["cancelled"]}).data)
