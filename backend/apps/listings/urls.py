"""Listing routes — mounted at /api/v1/listings/."""
from django.urls import path
from .views import ListingDetailView, ListingListCreateView, MyListingsView

urlpatterns = [
    path("", ListingListCreateView.as_view(), name="listing-list"),  # GET (public) / POST (verified supplier)
    path("my/", MyListingsView.as_view(), name="listing-my"),         # GET supplier's own listings, all statuses
    path("<int:pk>/", ListingDetailView.as_view(), name="listing-detail"),  # GET / PATCH / DELETE
]
