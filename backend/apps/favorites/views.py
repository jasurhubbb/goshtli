"""Favorite views — list own favorites, toggle (idempotent add/remove), check if a listing is favorited."""
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.listings.models import Listing
from .models import Favorite
from .serializers import FavoriteSerializer


class FavoriteListView(generics.ListAPIView):
    """GET /api/v1/favorites/ — current user's saved listings, newest first."""
    serializer_class = FavoriteSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Favorite.objects.none()
        # select_related on listing + supplier saves a JOIN per item when rendering the saved-listings screen
        return Favorite.objects.filter(user=self.request.user) \
            .select_related("listing", "listing__supplier", "listing__supplier__supplier_profile") \
            .prefetch_related("listing__photos")


@extend_schema(parameters=[OpenApiParameter("listing_pk", OpenApiTypes.INT, OpenApiParameter.PATH)],
               responses={201: FavoriteSerializer, 200: FavoriteSerializer})
class FavoriteToggleView(APIView):
    """POST /api/v1/favorites/{listing_pk}/ — add to favorites; DELETE removes. Both idempotent.

    Single endpoint instead of two (POST + DELETE) because the mobile heart-icon needs to flip state atomically.
    Returns the favorite row on POST (with 201 if newly created, 200 if it already existed).
    """
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, listing_pk):
        try: listing = Listing.objects.get(pk=listing_pk)
        except Listing.DoesNotExist: raise NotFound()
        fav, created = Favorite.objects.get_or_create(user=request.user, listing=listing)
        return Response(FavoriteSerializer(fav).data,
                        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    def delete(self, request, listing_pk):
        Favorite.objects.filter(user=request.user, listing_id=listing_pk).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
