"""Favorite routes — mounted at /api/v1/favorites/."""
from django.urls import path
from .views import FavoriteListView, FavoriteToggleView

urlpatterns = [
    path("", FavoriteListView.as_view(), name="favorite-list"),                            # GET own saved listings
    path("<int:listing_pk>/", FavoriteToggleView.as_view(), name="favorite-toggle"),        # POST add · DELETE remove
]
