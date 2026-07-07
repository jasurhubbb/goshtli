"""Order views — buyer-side (place, my, cancel) + supplier-side (list, status). All mutations go through the service layer.

Each view carries an @extend_schema decorator so drf-spectacular can document request/response shapes accurately;
APIView subclasses don't auto-introspect, and ListAPIViews need queryset guards because get_queryset() reads request.user
which is anonymous during schema generation.
"""
from django.core.exceptions import ValidationError as DjangoValidationError
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, status
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsBuyer, IsSupplier
from .models import Order
from .serializers import OrderCreateSerializer, OrderReadSerializer, OrderStatusUpdateSerializer
from .services import (CancellationNotAllowed, InsufficientStock, InvalidStatusTransition,
                       ListingNotOrderable, cancel_order, create_order, transition_order_status)


def _service_errors_to_drf(exc):
    """Translate our service-layer exceptions (Django ValidationError subclasses) into DRF 400 responses."""
    detail = getattr(exc, "message_dict", None) or getattr(exc, "messages", None) or [str(exc)]
    raise ValidationError(detail)


# ---------- Buyer-side ----------

@extend_schema(request=OrderCreateSerializer, responses={201: OrderReadSerializer},
               description="Buyer places an order. Backend atomically decrements listing stock and snapshots total_price.")
class OrderCreateView(APIView):
    """POST /api/v1/orders/ — buyer places an order. Delegates atomic stock+price logic to services.create_order()."""
    permission_classes = (IsBuyer,)

    def post(self, request):
        s = OrderCreateSerializer(data=request.data); s.is_valid(raise_exception=True)
        d = s.validated_data
        try:
            order = create_order(buyer=request.user, listing_id=d["listing"],
                                 quantity_kg=d["quantity_kg"],
                                 delivery_address=d["delivery_address"],
                                 notes=d.get("notes", ""),
                                 # v3.6 delivery + butcher params straight from the validated payload. The
                                 # service defaults each to its empty/zero so legacy clients (cart pre-PRD
                                 # delivery page) keep working without sending these.
                                 delivery_vehicle_type=d.get("delivery_vehicle_type", ""),
                                 delivery_time_slot=d.get("delivery_time_slot", ""),
                                 delivery_distance_km=d.get("delivery_distance_km", 0),
                                 delivery_lat=d.get("delivery_lat"),
                                 delivery_lng=d.get("delivery_lng"),
                                 delivery_price=d.get("delivery_price", 0),
                                 butcher_service_requested=d.get("butcher_service_requested", False),
                                 butcher_service_fee=d.get("butcher_service_fee", 0),
                                 # v3.9.15 — buyer's picked qassob from the Servislar tab or listing detail.
                                 preferred_qassob_id=d.get("preferred_qassob"))
        except (InsufficientStock, ListingNotOrderable, DjangoValidationError) as e:
            _service_errors_to_drf(e)
        return Response(OrderReadSerializer(order).data, status=status.HTTP_201_CREATED)


class MyOrdersView(generics.ListAPIView):
    """GET /api/v1/orders/my/ — buyer's own order history; supports ?status= filter."""
    serializer_class = OrderReadSerializer
    permission_classes = (IsBuyer,)
    filterset_fields = ("status",)
    ordering = ("-created_at",)

    def get_queryset(self):
        # During schema generation request.user is anonymous; return an empty qs so spectacular can introspect the model.
        if getattr(self, "swagger_fake_view", False): return Order.objects.none()
        return Order.objects.filter(buyer=self.request.user).select_related("listing", "listing__supplier", "buyer")


class OrderDetailView(generics.RetrieveAPIView):
    """GET /api/v1/orders/{id}/ — readable by the buyer who placed it OR the supplier whose listing it's on."""
    serializer_class = OrderReadSerializer
    queryset = Order.objects.select_related("listing", "listing__supplier", "buyer")

    def get_object(self):
        order = super().get_object()
        u = self.request.user
        if order.buyer_id != u.id and order.listing.supplier_id != u.id:
            raise NotFound()  # 404 instead of 403 to avoid leaking that the order exists at all
        return order


@extend_schema(request=None, responses={200: OrderReadSerializer},
               parameters=[OpenApiParameter("pk", OpenApiTypes.INT, OpenApiParameter.PATH)],
               description="Buyer cancels own PENDING order. Backend restores stock atomically and may flip listing back to ACTIVE.")
class OrderCancelView(APIView):
    """POST /api/v1/orders/{id}/cancel/ — buyer cancels own PENDING order; supplier cancellations go through the status endpoint."""
    permission_classes = (IsBuyer,)

    def post(self, request, pk):
        try: order = cancel_order(order_id=pk, by_user=request.user)
        except Order.DoesNotExist: raise NotFound()
        except (CancellationNotAllowed, DjangoValidationError) as e: _service_errors_to_drf(e)
        return Response(OrderReadSerializer(order).data)


@extend_schema(request=None, responses={200: OrderReadSerializer},
               parameters=[OpenApiParameter("pk", OpenApiTypes.INT, OpenApiParameter.PATH)],
               description="v3.9.14 — buyer confirms receipt after courier marked arrival "
                           "(DELIVERED_PENDING_CONFIRMATION → DELIVERED). Rejects other transitions.")
class OrderConfirmDeliveryView(APIView):
    """POST /api/v1/orders/{id}/confirm-delivery/ — buyer's "Buyurtmani qabul qildim" button.

    Last step in the fulfilment lifecycle. Only the ORDER's buyer can call this, and only from
    DELIVERED_PENDING_CONFIRMATION. Mirrors the receipt-confirmation flow in Uzum Tezkor / Wolt.
    Kept separate from the supplier's status endpoint so the buyer's confirmation intent is
    explicit in the URL — no accidental supplier-driven "auto-confirm".
    """
    permission_classes = (IsBuyer,)

    def post(self, request, pk):
        from .services import BUYER_CONFIRMABLE_FROM
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            raise NotFound()
        if order.buyer_id != request.user.id:
            raise PermissionDenied("Not your order.")
        if order.status not in BUYER_CONFIRMABLE_FROM:
            return Response({"detail":
                f"Order status is {order.status}, cannot confirm delivery from that state."},
                status=status.HTTP_400_BAD_REQUEST)
        order.status = Order.Status.DELIVERED
        order.save(update_fields=("status", "updated_at"))
        return Response(OrderReadSerializer(order).data)


# ---------- Supplier-side ----------

class SupplierOrdersView(generics.ListAPIView):
    """GET /api/v1/orders/supplier/ — orders placed against this supplier's listings; supports ?status= filter."""
    serializer_class = OrderReadSerializer
    permission_classes = (IsSupplier,)
    filterset_fields = ("status",)
    ordering = ("-created_at",)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Order.objects.none()
        return Order.objects.filter(listing__supplier=self.request.user).select_related("listing", "listing__supplier", "buyer")


@extend_schema(request=OrderStatusUpdateSerializer, responses={200: OrderReadSerializer},
               parameters=[OpenApiParameter("pk", OpenApiTypes.INT, OpenApiParameter.PATH)],
               description="Supplier transitions order through the state machine. CANCELLED routes through cancel_order to restore stock.")
class SupplierOrderStatusView(APIView):
    """POST /api/v1/orders/supplier/{id}/status/ — drives the order through the state machine. CANCEL also restores stock."""
    permission_classes = (IsSupplier,)

    def post(self, request, pk):
        s = OrderStatusUpdateSerializer(data=request.data); s.is_valid(raise_exception=True)
        try: order = transition_order_status(order_id=pk, new_status=s.validated_data["status"], by_user=request.user)
        except Order.DoesNotExist: raise NotFound()
        except InvalidStatusTransition as e: raise PermissionDenied(str(e))
        except (CancellationNotAllowed, DjangoValidationError) as e: _service_errors_to_drf(e)
        return Response(OrderReadSerializer(order).data)
