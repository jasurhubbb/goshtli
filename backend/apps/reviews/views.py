"""Review views — create (one per delivered order, buyer-only), list (filter by supplier), supplier rating aggregate."""
from django.db.models import Avg, Count
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Review
from .serializers import ReviewCreateSerializer, ReviewSerializer


class ReviewListCreateView(generics.ListCreateAPIView):
    """GET /api/v1/reviews/?supplier=<id> — list reviews for a supplier (paginated). POST creates one."""
    serializer_class = ReviewSerializer
    permission_classes = (permissions.IsAuthenticated,)
    filterset_fields = ("supplier",)
    ordering = ("-created_at",)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Review.objects.none()
        return Review.objects.select_related("buyer", "supplier")

    def create(self, request, *args, **kwargs):
        # Use the dedicated CreateSerializer for input validation; respond with the public ReviewSerializer shape
        s = ReviewCreateSerializer(data=request.data, context={"request": request})
        s.is_valid(raise_exception=True)
        review = s.save()
        return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)


@extend_schema(parameters=[OpenApiParameter("supplier_id", OpenApiTypes.INT, OpenApiParameter.PATH)],
               responses={200: {"type": "object", "properties": {
                   "supplier_id": {"type": "integer"}, "avg_rating": {"type": "number"}, "count": {"type": "integer"}}}})
class SupplierRatingView(APIView):
    """GET /api/v1/reviews/supplier/{supplier_id}/aggregate/ — avg rating + count for a supplier's listing detail page."""
    permission_classes = (permissions.AllowAny,)  # public — buyers comparing suppliers don't need auth

    def get(self, request, supplier_id):
        agg = Review.objects.filter(supplier_id=supplier_id).aggregate(avg=Avg("rating"), n=Count("id"))
        return Response({"supplier_id": supplier_id, "avg_rating": round(agg["avg"] or 0, 2), "count": agg["n"] or 0})
