"""Buyer views — /me profile and /dashboard order summary."""
from django.db.models import Count, Q
from drf_spectacular.utils import extend_schema
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsBuyer
from apps.orders.models import Order
from rest_framework import permissions
from rest_framework.exceptions import NotFound
from .models import BuyerProfile, SavedAddress
from .serializers import BuyerDashboardSerializer, BuyerProfileSerializer, SavedAddressSerializer


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


class SavedAddressListCreateView(generics.ListCreateAPIView):
    """GET /api/v1/buyers/addresses/ — list current user's saved addresses (default first). POST creates a new one."""
    serializer_class = SavedAddressSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return SavedAddress.objects.none()
        return SavedAddress.objects.filter(user=self.request.user)

    def perform_create(self, serializer): serializer.save(user=self.request.user)


class SavedAddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /api/v1/buyers/addresses/{id}/ — owner-only mutations."""
    serializer_class = SavedAddressSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return SavedAddress.objects.none()
        return SavedAddress.objects.filter(user=self.request.user)
