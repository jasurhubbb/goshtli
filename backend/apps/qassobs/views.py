"""Qassob endpoints — owner-CRUD (`/qassobs/me/`) + public discovery (`/qassobs/`).

Public list/detail feed the buyer-app Servislar tab. Owner CRUD feeds the partner-app Profil + Bosh
sahifa toggles + Servisim CRUD (v3.9).
"""
import math

from drf_spectacular.utils import OpenApiParameter, OpenApiTypes, extend_schema
from django.shortcuts import get_object_or_404
from django_filters import rest_framework as filters
from rest_framework import generics, parsers, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsQassob
from .models import QassobPhoto, QassobProfile
from .serializers import (AvailabilityToggleSerializer, CapacityUpdateSerializer,
                          QassobMeSerializer, QassobPhotoSerializer, QassobPublicSerializer)


class QassobMeView(generics.GenericAPIView):
    """GET/POST/PATCH /api/v1/qassobs/me/ — owner CRUD.

    POST creates the profile on first call from the onboarding wizard's submit page; subsequent PATCHes
    edit it. GET returns the current shape (with photo_url so the partner-app can render the avatar).

    Accepts both JSON and multipart/form-data so the partner-app profile-edit page can PATCH the
    avatar file in the same request as the rest of the structured fields.
    """
    permission_classes = (IsQassob,)
    serializer_class = QassobMeSerializer
    parser_classes = (parsers.JSONParser, parsers.MultiPartParser, parsers.FormParser)

    def _get_or_create(self, request):
        # v3.9.16 — auto-create the profile so /me/ is ALWAYS 200, mirroring SupplierMeView. Qassobs are now
        # admin-provisioned; a User created via the Django-admin "Add user" form (or any path that skips the
        # provisioning helper) has no profile, and the app's tabs would 404 ("profil topilmadi") without this.
        # The setup wizard then fills the empty fields. is_verified=True matches the legacy POST behavior.
        profile, _ = QassobProfile.objects.get_or_create(
            user=request.user,
            defaults={"full_name": request.user.full_name or "", "years_experience": 0,
                      "region": "", "address": "", "is_verified": True})
        return profile

    def get(self, request):
        return Response(self.get_serializer(self._get_or_create(request)).data)

    def post(self, request):
        # Upsert — GET now auto-creates the profile, so the wizard's submit finds an existing row; update it
        # rather than 409-ing. Kept as POST for back-compat with the wizard's submit call.
        profile = self._get_or_create(request)
        s = self.get_serializer(profile, data=request.data, partial=True); s.is_valid(raise_exception=True)
        s.save()
        return Response(self.get_serializer(profile).data)

    def patch(self, request):
        profile = self._get_or_create(request)
        s = self.get_serializer(profile, data=request.data, partial=True); s.is_valid(raise_exception=True)
        s.save()
        return Response(s.data)


class QassobAvailabilityView(APIView):
    """POST /qassobs/me/availability/ — F1 Open/Closed toggle. Fast write — single boolean."""
    permission_classes = (IsQassob,)

    def post(self, request):
        s = AvailabilityToggleSerializer(data=request.data); s.is_valid(raise_exception=True)
        QassobProfile.objects.filter(user=request.user).update(is_open_now=s.validated_data["is_open_now"])
        return Response({"is_open_now": s.validated_data["is_open_now"]})


class QassobCapacityView(APIView):
    """POST /qassobs/me/capacity/ — F8 daily capacity slider."""
    permission_classes = (IsQassob,)

    def post(self, request):
        s = CapacityUpdateSerializer(data=request.data); s.is_valid(raise_exception=True)
        QassobProfile.objects.filter(user=request.user).update(
            daily_capacity_head=s.validated_data["daily_capacity_head"])
        return Response({"daily_capacity_head": s.validated_data["daily_capacity_head"]})


# ---------------- Public discovery (Servislar tab) ----------------

class QassobFilterSet(filters.FilterSet):
    """django-filter spec for the public list endpoint."""
    region = filters.CharFilter(field_name="region", lookup_expr="iexact")
    animal = filters.CharFilter(method="filter_animal", label="One of MOL/QOY/ECHKI/OT")
    service = filters.CharFilter(method="filter_service", label="'slaughter' filters to is_slaughterhouse=True")

    def filter_animal(self, qs, name, value):
        # animals_supported is a JSON list; Postgres `JSONField`'s contains lookup matches arrays.
        return qs.filter(animals_supported__contains=[value]) if value else qs

    def filter_service(self, qs, name, value):
        return qs.filter(is_slaughterhouse=True) if value == "slaughter" else qs

    class Meta:
        model = QassobProfile
        fields = ("region", "animal", "service")


class QassobListView(generics.ListAPIView):
    """GET /api/v1/qassobs/ — buyer-app Servislar tab.

    Public. Only returns is_verified=True and is_open_now=True rows by default; the buyer-side filter
    chips drill down further. Supports radius filtering via `?buyer_lat=&buyer_lng=&radius_km=`.
    """
    permission_classes = (permissions.AllowAny,)
    serializer_class = QassobPublicSerializer
    filter_backends = (filters.DjangoFilterBackend,)
    filterset_class = QassobFilterSet
    pagination_class = None      # buyer-app renders a horizontal carousel; no pagination needed for v1

    def get_queryset(self):
        qs = QassobProfile.objects.filter(is_verified=True).select_related("user")
        # Hide closed qassobs by default — buyer can opt in via `?include_closed=1` later if needed.
        if self.request.query_params.get("include_closed") != "1":
            qs = qs.filter(is_open_now=True)
        # Radius filter — compute haversine in Python (low cardinality + small DB). Switch to PostGIS
        # if the buyer base grows past ~10k qassobs and this becomes a bottleneck.
        try:
            blat = float(self.request.query_params.get("buyer_lat", ""))
            blng = float(self.request.query_params.get("buyer_lng", ""))
            radius = float(self.request.query_params.get("radius_km", "1000"))
        except (TypeError, ValueError):
            blat = blng = radius = None
        if blat is not None and blng is not None:
            keep = []
            for q in qs:
                if q.lat is None or q.lng is None: continue
                if _haversine_km(blat, blng, float(q.lat), float(q.lng)) <= radius:
                    keep.append(q.id)
            qs = qs.filter(id__in=keep)
        # Default sort: highest rating first, ties broken by newest. Buyer can override via DRF `?ordering=`.
        sort = self.request.query_params.get("sort", "")
        if sort == "distance" and blat is not None:
            # Already filtered above; reorder in Python by distance for response stability.
            return sorted(qs, key=lambda q: _haversine_km(blat, blng, float(q.lat), float(q.lng)))
        if sort == "experience":
            return qs.order_by("-years_experience")
        return qs.order_by("-rating_avg", "-created_at")


class QassobDetailView(generics.RetrieveAPIView):
    """GET /api/v1/qassobs/{id}/ — buyer-app card detail. Public + always verified."""
    permission_classes = (permissions.AllowAny,)
    serializer_class = QassobPublicSerializer
    queryset = QassobProfile.objects.filter(is_verified=True).select_related("user")


class QassobCallbackRequestView(APIView):
    """POST /api/v1/qassobs/<id>/callback/  {phone, note?}

    v3.9.14 — buyer's alternative to opening a chat: leave a phone number and note. Creates an
    in-app Notification row on the qassob's side + fires an FCM push so the qassob sees the callback
    request in Bildirishnomalar. Anonymous callers allowed (buyer doesn't need to sign in just to
    leave a phone).
    """
    permission_classes = (permissions.AllowAny,)

    def post(self, request, pk):
        phone = (request.data.get("phone") or "").strip()
        note = (request.data.get("note") or "").strip()
        if not phone:
            return Response({"phone": "Telefon raqami majburiy."},
                            status=status.HTTP_400_BAD_REQUEST)
        try:
            qassob = QassobProfile.objects.select_related("user").get(pk=pk, is_verified=True)
        except QassobProfile.DoesNotExist:
            return Response({"detail": "Qassob topilmadi."}, status=status.HTTP_404_NOT_FOUND)
        # Compose a compact, actionable notification the qassob can tap-to-call directly. The
        # `tel:` uri lives in the `link` field so the mobile can render a Call button on the row.
        title = "Yangi qo'ng'iroq so'rovi"
        message = f"Buyer telefon raqamini qoldirdi: {phone}"
        if note:
            message += f"\nIzoh: {note[:200]}"
        try:
            from apps.notifications.models import Notification
            from apps.notifications.fcm import send_to_user
            Notification.objects.create(
                user=qassob.user, kind=Notification.Kind.OTHER,
                title=title, message=message, link=f"tel:{phone}")
            send_to_user(qassob.user, title=title, body=message, link=f"tel:{phone}",
                          kind="CALLBACK_REQUEST",
                          extra={"phone": phone, "qassob_id": qassob.pk})
        except Exception:
            # Best-effort push — don't fail the buyer's request if FCM cert is missing.
            pass
        return Response({"detail": "Qassob sizga qo'ng'iroq qiladi."},
                        status=status.HTTP_201_CREATED)


def _haversine_km(lat1, lng1, lat2, lng2):
    r = 6371.0
    lat1, lat2 = math.radians(lat1), math.radians(lat2)
    dlat = lat2 - lat1
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng/2)**2
    return 2 * r * math.asin(math.sqrt(a))


# ============================================================================
# v3.9 — Gallery CRUD. Multipart uploads can't ride on the existing /qassobs/me/
# PATCH cleanly (DRF doesn't compose multipart + nested writes well), so the
# gallery gets its own owner-scoped endpoints. List+create at /me/photos/,
# delete at /me/photos/<pk>/. Reorder is a single bulk-PATCH at /me/photos/
# reorder/ that accepts {ids: [...]} so the partner-app's drag-reorder UI can
# persist a new order in one round-trip.
# ============================================================================

class QassobGalleryListCreateView(generics.ListCreateAPIView):
    """GET / POST /api/v1/qassobs/me/photos/ — owner reads + multipart upload.

    Position auto-increments on create so each new photo lands at the end of the strip.
    """
    permission_classes = (IsQassob,)
    serializer_class = QassobPhotoSerializer
    parser_classes = (parsers.MultiPartParser, parsers.FormParser)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return QassobPhoto.objects.none()
        return QassobPhoto.objects.filter(qassob__user=self.request.user)

    def perform_create(self, serializer):
        qassob = get_object_or_404(QassobProfile, user=self.request.user)
        next_pos = (QassobPhoto.objects.filter(qassob=qassob)
                    .order_by("-position").values_list("position", flat=True).first() or 0) + 1
        serializer.save(qassob=qassob, position=next_pos)


@extend_schema(parameters=[OpenApiParameter("pk", OpenApiTypes.INT, OpenApiParameter.PATH)])
class QassobGalleryDeleteView(generics.DestroyAPIView):
    """DELETE /api/v1/qassobs/me/photos/<pk>/ — owner-only. 404 if pk belongs to another qassob (we
    refuse to leak cross-account existence)."""
    permission_classes = (IsQassob,)
    serializer_class = QassobPhotoSerializer

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return QassobPhoto.objects.none()
        return QassobPhoto.objects.filter(qassob__user=self.request.user)


@extend_schema(
    request={"type": "object", "properties": {"ids": {"type": "array", "items": {"type": "integer"}}},
             "required": ["ids"]},
    responses={200: QassobPhotoSerializer(many=True)},
    description="POST {ids: [photo_id, …]} reorders the caller's gallery to match the array's index. "
                "Atomic — partial updates leave the gallery in its original order.")
class QassobGalleryReorderView(APIView):
    """POST /api/v1/qassobs/me/photos/reorder/ — single-roundtrip reorder for the drag-handle UI.

    `ids` must be a permutation of the caller's full gallery. Any unknown id or missing id raises 400
    so the client knows to refetch instead of persisting a half-reorder.
    """
    permission_classes = (IsQassob,)

    def post(self, request):
        ids = request.data.get("ids", None)
        if not isinstance(ids, list) or not all(isinstance(i, int) for i in ids):
            return Response({"detail": "Body must be {ids: [int, int, ...]}."},
                            status=status.HTTP_400_BAD_REQUEST)
        qs = QassobPhoto.objects.filter(qassob__user=request.user)
        owned_ids = set(qs.values_list("id", flat=True))
        if set(ids) != owned_ids:
            return Response({"detail": "ids must be a permutation of your full gallery — refetch and retry."},
                            status=status.HTTP_400_BAD_REQUEST)
        from django.db import transaction
        with transaction.atomic():
            for pos, pid in enumerate(ids, start=1):
                QassobPhoto.objects.filter(pk=pid).update(position=pos)
        fresh = QassobPhoto.objects.filter(qassob__user=request.user).order_by("position")
        return Response(QassobPhotoSerializer(fresh, many=True, context={"request": request}).data)
