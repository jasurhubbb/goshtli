"""Listing routes — mounted at /api/v1/listings/.

v2 adds the two photo routes nested under each listing.
"""
from django.urls import path
from .views import (ListingDetailView, ListingListCreateView, ListingPhotoDeleteView,
                    ListingPhotoUploadView, MyListingsView)

urlpatterns = [
    path("", ListingListCreateView.as_view(), name="listing-list"),                # GET (public) / POST (verified supplier)
    path("my/", MyListingsView.as_view(), name="listing-my"),                       # GET supplier's own listings
    path("<int:pk>/", ListingDetailView.as_view(), name="listing-detail"),           # GET / PATCH / DELETE
    # Nested photo routes — owner-only mutations, photos are read-inline via ListingSerializer
    path("<int:listing_pk>/photos/", ListingPhotoUploadView.as_view(), name="listing-photo-upload"),
    path("<int:listing_pk>/photos/<int:pk>/", ListingPhotoDeleteView.as_view(), name="listing-photo-delete"),
]
