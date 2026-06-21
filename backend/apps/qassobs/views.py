"""Qassob endpoints — owner-CRUD (`/qassobs/me/`) + public discovery (`/qassobs/`).

Public list/detail feed the buyer-app Servislar tab. Owner CRUD feeds the partner-app Profil + Bosh
sahifa toggles.
"""
import math

from django.shortcuts import get_object_or_404
from django_filters import rest_framework as filters
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import IsQassob
from .models import QassobProfile
from .serializers import (AvailabilityToggleSerializer, CapacityUpdateSerializer,
                          QassobMeSerializer, QassobPublicSerializer)


class QassobMeView(generics.GenericAPIView):
    """GET/POST/PATCH /api/v1/qassobs/me/ — owner CRUD.

    POST creates the profile on first call from the onboarding wizard's submit page; subsequent PATCHes
    edit it. GET returns the current shape (with photo_url so the partner-app can render the avatar).
    """
    permission_classes = (IsQassob,)
    serializer_class = QassobMeSerializer

    def _get_or_none(self, request):
        try: return QassobProfile.objects.get(user=request.user)
        except QassobProfile.DoesNotExist: return None

    def get(self, request):
        profile = self._get_or_none(request)
        if not profile:
            return Response({"detail": "Qassob profile not created yet."}, status=status.HTTP_404_NOT_FOUND)
        return Response(self.get_serializer(profile).data)

    def post(self, request):
        if self._get_or_none(request) is not None:
            return Response({"detail": "Already exists — use PATCH to edit."}, status=status.HTTP_409_CONFLICT)
        s = self.get_serializer(data=request.data); s.is_valid(raise_exception=True)
        # v3.8.2: auto-verify on creation — see suppliers/signals.py for rationale (KYC review queue
        # deferred). Keeping IsVerifiedQassob in the permission class for future re-enable.
        profile = QassobProfile.objects.create(user=request.user, is_verified=True, **s.validated_data)
        return Response(self.get_serializer(profile).data, status=status.HTTP_201_CREATED)

    def patch(self, request):
        profile = self._get_or_none(request)
        if not profile:
            return Response({"detail": "Create the profile first via POST."}, status=status.HTTP_404_NOT_FOUND)
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


def _haversine_km(lat1, lng1, lat2, lng2):
    r = 6371.0
    lat1, lat2 = math.radians(lat1), math.radians(lat2)
    dlat = lat2 - lat1
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng/2)**2
    return 2 * r * math.asin(math.sqrt(a))
