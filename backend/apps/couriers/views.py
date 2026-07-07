"""Courier-side REST views. All under /api/v1/couriers/ per config/urls.py wiring.

Design notes:
  • Every mutation goes through the service layer helper `_advance_delivery_status()` so the state
    machine + order-side side-effects stay in one place.
  • DELIVERED (courier-side) flips the parent Order to DELIVERED_PENDING_CONFIRMATION. The buyer
    then confirms via /orders/<id>/confirm-delivery/ — two-step to prevent "was it really
    delivered?" disputes.
  • Earnings aggregation is a single COUNT + SUM per bucket; cheap enough to serve on every
    dashboard open.
"""
from datetime import date, datetime, timedelta
from decimal import Decimal

from django.db import transaction
from django.db.models import Count, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from drf_spectacular.utils import OpenApiParameter, OpenApiTypes, extend_schema
from rest_framework import generics, parsers, permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsCourierOrSelfDeliveringSupplier
from apps.notifications.fcm import send_to_user
from apps.notifications.models import Notification
from apps.orders.models import Order
from .models import CourierProfile, Delivery
from .serializers import (CourierMeSerializer, DeliveryDetailSerializer,
                          DeliveryListSerializer, DeliveryProofUploadSerializer,
                          DeliveryStatusUpdateSerializer)


# ---------- Profile CRUD ----------

class CourierMeView(generics.GenericAPIView):
    """GET/POST/PATCH /api/v1/couriers/me/ — owner CRUD. Auto-creates the profile on first GET so
    a freshly-promoted COURIER account doesn't need to POST manually. Accepts multipart so the
    photo field can ride the same PATCH as text fields."""
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)
    serializer_class = CourierMeSerializer
    parser_classes = (parsers.JSONParser, parsers.MultiPartParser, parsers.FormParser)

    def _get_or_create(self, request):
        profile, _ = CourierProfile.objects.get_or_create(
            user=request.user,
            defaults={"full_name": request.user.full_name or ""})
        return profile

    def get(self, request):
        return Response(self.get_serializer(self._get_or_create(request)).data)

    def post(self, request):
        # Kept for symmetry with qassobs/suppliers; PATCH already handles creation via _get_or_create.
        profile = self._get_or_create(request)
        s = self.get_serializer(profile, data=request.data, partial=True); s.is_valid(raise_exception=True)
        s.save()
        return Response(s.data, status=status.HTTP_200_OK)

    def patch(self, request):
        profile = self._get_or_create(request)
        s = self.get_serializer(profile, data=request.data, partial=True); s.is_valid(raise_exception=True)
        s.save()
        return Response(s.data)


class CourierAvailabilityView(APIView):
    """POST /api/v1/couriers/me/availability/ {is_online: bool} — quick toggle for the Queue tab
    header switch. Auto-assignment only picks from is_online=True couriers."""
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)

    def post(self, request):
        val = request.data.get("is_online")
        if not isinstance(val, bool):
            return Response({"detail": "is_online must be boolean."},
                            status=status.HTTP_400_BAD_REQUEST)
        profile, _ = CourierProfile.objects.get_or_create(
            user=request.user, defaults={"full_name": request.user.full_name or ""})
        profile.is_online = val
        profile.save(update_fields=("is_online", "updated_at"))
        return Response({"is_online": profile.is_online})


# ---------- Queue / active deliveries ----------

class CourierQueueView(generics.ListAPIView):
    """GET /api/v1/couriers/me/deliveries/?bucket=queue|active|done

    * queue  — status=ASSIGNED (waiting for me to pick up)
    * active — status in {PICKED_UP, EN_ROUTE, ARRIVED} (in-progress)
    * done   — status in {DELIVERED, CANCELLED} (history)
    """
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)
    serializer_class = DeliveryListSerializer
    pagination_class = None

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Delivery.objects.none()
        bucket = self.request.query_params.get("bucket", "queue")
        qs = (Delivery.objects
              .filter(courier=self.request.user)
              .select_related("order", "order__buyer", "order__listing", "order__listing__market")
              .order_by("-created_at"))
        if bucket == "queue":
            return qs.filter(status=Delivery.Status.ASSIGNED)
        if bucket == "active":
            return qs.filter(status__in=(Delivery.Status.PICKED_UP,
                                          Delivery.Status.EN_ROUTE,
                                          Delivery.Status.ARRIVED))
        return qs.filter(status__in=(Delivery.Status.DELIVERED, Delivery.Status.CANCELLED))


class CourierDeliveryDetailView(generics.RetrieveAPIView):
    """GET /api/v1/couriers/me/deliveries/<pk>/ — full detail shape."""
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)
    serializer_class = DeliveryDetailSerializer

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Delivery.objects.none()
        return (Delivery.objects
                .filter(courier=self.request.user)
                .select_related("order", "order__buyer", "order__listing", "order__listing__market"))


# ---------- Status advance ----------

# Courier state machine — matches the buyer/supplier expectations for real-world dispatch.
COURIER_TRANSITIONS = {
    Delivery.Status.ASSIGNED: {Delivery.Status.PICKED_UP, Delivery.Status.CANCELLED},
    Delivery.Status.PICKED_UP: {Delivery.Status.EN_ROUTE, Delivery.Status.CANCELLED},
    Delivery.Status.EN_ROUTE: {Delivery.Status.ARRIVED, Delivery.Status.CANCELLED},
    Delivery.Status.ARRIVED: {Delivery.Status.DELIVERED, Delivery.Status.CANCELLED},
    # DELIVERED + CANCELLED are terminal.
}


@extend_schema(request=DeliveryStatusUpdateSerializer,
               responses={200: DeliveryDetailSerializer},
               parameters=[OpenApiParameter("pk", OpenApiTypes.INT, OpenApiParameter.PATH)])
class CourierDeliveryStatusView(APIView):
    """POST /api/v1/couriers/me/deliveries/<pk>/status/ {status, cash_collected_uzs?}

    * Enforces COURIER_TRANSITIONS.
    * When status=DELIVERED, ALSO flips the parent Order to DELIVERED_PENDING_CONFIRMATION and
      fires an FCM push to the buyer telling them to tap "Buyurtmani qabul qildim". Stamps
      delivered_at + payout_uzs (currently a placeholder computation — swap with the platform's
      actual rate card later).
    * When cash_collected_uzs is included on the DELIVERED transition, we snapshot it.
    """
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)

    def post(self, request, pk):
        s = DeliveryStatusUpdateSerializer(data=request.data); s.is_valid(raise_exception=True)
        new_status = s.validated_data["status"]
        cash = s.validated_data.get("cash_collected_uzs")
        try:
            delivery = (Delivery.objects
                        .select_related("order", "order__buyer", "order__listing")
                        .get(pk=pk, courier=request.user))
        except Delivery.DoesNotExist:
            raise NotFound()
        allowed = COURIER_TRANSITIONS.get(delivery.status, set())
        if new_status not in allowed:
            return Response({"detail": f"Cannot go from {delivery.status} to {new_status}."},
                            status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            delivery.status = new_status
            if new_status == Delivery.Status.PICKED_UP:
                delivery.picked_up_at = timezone.now()
            if new_status == Delivery.Status.DELIVERED:
                delivery.delivered_at = timezone.now()
                # v3.9.15 — placeholder payout math: 8% of the order total, floor 5000. Swap with
                # your real rate card once ops signs off.
                total = int(Decimal(delivery.order.total_price or 0))
                delivery.payout_uzs = max(5000, total * 8 // 100)
                if cash is not None: delivery.cash_collected_uzs = int(cash)
                # Flip the parent Order state so the buyer sees the "confirm receipt" button.
                delivery.order.status = Order.Status.DELIVERED_PENDING_CONFIRMATION
                delivery.order.save(update_fields=("status", "updated_at"))
                _fire_buyer_confirm_reminder(delivery)
            delivery.save()

        return Response(DeliveryDetailSerializer(delivery, context={"request": request}).data)


def _fire_buyer_confirm_reminder(delivery: Delivery) -> None:
    """Best-effort in-app notification + FCM: buyer needs to tap 'Buyurtmani qabul qildim'."""
    try:
        title = f"Buyurtma #{delivery.order_id} eshigingizda"
        message = "Kuryer paketni topshirdi. Ilovada 'Buyurtmani qabul qildim' tugmasini bosing."
        Notification.objects.create(
            user=delivery.order.buyer, kind=Notification.Kind.OTHER,
            title=title, message=message, link=f"/orders/{delivery.order_id}")
        send_to_user(delivery.order.buyer, title=title, body=message,
                     link=f"/orders/{delivery.order_id}",
                     kind="ORDER_STATUS_CHANGED",
                     extra={"order_id": delivery.order_id,
                            "status": Order.Status.DELIVERED_PENDING_CONFIRMATION})
    except Exception:
        return


@extend_schema(request={"multipart/form-data": {
                    "type": "object",
                    "properties": {"proof_photo": {"type": "string", "format": "binary"}}}},
               responses={200: DeliveryDetailSerializer})
class CourierDeliveryProofView(APIView):
    """POST /api/v1/couriers/me/deliveries/<pk>/proof/ — multipart photo upload for delivery
    confirmation. Doesn't change status; just attaches the file so ops has proof in disputes."""
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)
    parser_classes = (parsers.MultiPartParser, parsers.FormParser)

    def post(self, request, pk):
        try:
            delivery = Delivery.objects.get(pk=pk, courier=request.user)
        except Delivery.DoesNotExist:
            raise NotFound()
        photo = request.FILES.get("proof_photo")
        if photo is None:
            return Response({"proof_photo": "File is required."},
                            status=status.HTTP_400_BAD_REQUEST)
        delivery.proof_photo = photo
        delivery.save(update_fields=("proof_photo", "updated_at"))
        return Response(DeliveryDetailSerializer(delivery, context={"request": request}).data)


# ---------- Dashboard aggregates ----------

class CourierDashboardView(APIView):
    """GET /api/v1/couriers/me/dashboard/ — home-screen KPIs in ONE round-trip.

    Numbers:
      • today_earnings / today_deliveries  — the 4-hour-old rolling window most driver apps show
      • active_count                        — in-progress right now (bucket=active count)
      • queue_count                         — waiting to pick up (bucket=queue count)
      • lifetime_deliveries / rating_avg    — the trust signal in the header
    """
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)

    def get(self, request):
        u = request.user
        since = timezone.now() - timedelta(hours=24)
        today = (Delivery.objects.filter(courier=u,
                                          status=Delivery.Status.DELIVERED,
                                          delivered_at__gte=since)
                 .aggregate(count=Count("id"), sum=Sum("payout_uzs")))
        queue_count = Delivery.objects.filter(
            courier=u, status=Delivery.Status.ASSIGNED).count()
        active_count = Delivery.objects.filter(
            courier=u,
            status__in=(Delivery.Status.PICKED_UP,
                        Delivery.Status.EN_ROUTE,
                        Delivery.Status.ARRIVED)).count()
        profile = getattr(u, "courier_profile", None)
        return Response({
            "today_earnings_uzs": int(today["sum"] or 0),
            "today_deliveries": today["count"] or 0,
            "queue_count": queue_count,
            "active_count": active_count,
            "lifetime_deliveries": getattr(profile, "lifetime_deliveries", 0),
            "lifetime_earnings_uzs": getattr(profile, "lifetime_earnings_uzs", 0),
            "rating_avg": str(getattr(profile, "rating_avg", 0)),
            "rating_count": getattr(profile, "rating_count", 0),
            "is_online": getattr(profile, "is_online", False),
            "vehicle_kind": getattr(profile, "vehicle_kind", ""),
        })


class CourierEarningsView(APIView):
    """GET /api/v1/couriers/me/earnings/?period=day|week|month

    Returns the aggregate + a 7-point time series for the fl_chart trend line on the Earnings tab.
    """
    permission_classes = (IsCourierOrSelfDeliveringSupplier,)

    def get(self, request):
        period = request.query_params.get("period", "week")
        today_local = timezone.localdate()
        if period == "day":
            start = today_local; buckets = 1
        elif period == "month":
            start = today_local - timedelta(days=30); buckets = 30
        else:
            start = today_local - timedelta(days=7); buckets = 7

        delivered = (Delivery.objects
                     .filter(courier=request.user,
                             status=Delivery.Status.DELIVERED,
                             delivered_at__date__gte=start))
        total_sum = delivered.aggregate(s=Sum("payout_uzs"))["s"] or 0
        total_count = delivered.count()

        # Per-day series — cheap because we already have `delivered` filtered
        series = []
        for i in range(buckets):
            d = start + timedelta(days=i)
            day_agg = delivered.filter(delivered_at__date=d).aggregate(
                s=Sum("payout_uzs"), c=Count("id"))
            series.append({"date": d.isoformat(),
                           "earnings_uzs": int(day_agg["s"] or 0),
                           "deliveries": day_agg["c"] or 0})

        return Response({
            "period": period,
            "total_earnings_uzs": int(total_sum),
            "total_deliveries": total_count,
            "series": series,
        })


# ---------- Admin: provision a courier account ----------

class AdminProvisionCourierView(APIView):
    """POST /api/v1/couriers/admin/provision/ {email, full_name, phone, password?}

    Admin-only. Creates a role=COURIER User + a CourierProfile in one shot. When `password` is
    absent, we generate a random 8-char code + return it in the response so the admin can hand it
    to the courier. Idempotent on email — if the user exists, we just re-provision.
    """
    permission_classes = (permissions.IsAdminUser,)                              # Django is_staff gate

    def post(self, request):
        from django.contrib.auth import get_user_model
        User = get_user_model()
        email = (request.data.get("email") or "").strip().lower()
        full_name = (request.data.get("full_name") or "").strip()
        phone = (request.data.get("phone") or "").strip()
        password = (request.data.get("password") or "").strip()
        if not email:
            return Response({"detail": "email is required"}, status=status.HTTP_400_BAD_REQUEST)
        if not password:
            import secrets
            password = secrets.token_urlsafe(6)[:8]
        user, created = User.objects.get_or_create(
            email=email, defaults={"full_name": full_name, "phone": phone,
                                    "role": User.Role.COURIER})
        if not created:
            user.role = User.Role.COURIER
            if full_name: user.full_name = full_name
            if phone: user.phone = phone
        user.set_password(password)
        user.save()
        CourierProfile.objects.get_or_create(user=user,
                                              defaults={"full_name": user.full_name or ""})
        return Response({"email": email, "password": password, "created": created},
                         status=status.HTTP_201_CREATED)
