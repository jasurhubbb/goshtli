"""Qassob URL routes. Mounted at /api/v1/qassobs/ from config/urls.py."""
from django.urls import path

from .views import (QassobAvailabilityView, QassobCapacityView, QassobDetailView,
                    QassobGalleryDeleteView, QassobGalleryListCreateView,
                    QassobGalleryReorderView, QassobListView, QassobMeView)

urlpatterns = [
    # Owner CRUD — used by the partner-app onboarding final submit + Profil/Servisim edit page
    path("me/", QassobMeView.as_view(), name="qassobs-me"),
    # Quick toggles for F1 + F8
    path("me/availability/", QassobAvailabilityView.as_view(), name="qassobs-me-availability"),
    path("me/capacity/", QassobCapacityView.as_view(), name="qassobs-me-capacity"),
    # v3.9 — Gallery CRUD. /reorder/ MUST come before /<int:pk>/ so the literal route doesn't get
    # swallowed by the pk converter.
    path("me/photos/", QassobGalleryListCreateView.as_view(), name="qassobs-me-photos"),
    path("me/photos/reorder/", QassobGalleryReorderView.as_view(), name="qassobs-me-photos-reorder"),
    path("me/photos/<int:pk>/", QassobGalleryDeleteView.as_view(), name="qassobs-me-photos-detail"),
    # Public discovery — buyer-app Servislar tab
    path("", QassobListView.as_view(), name="qassobs-list"),
    path("<int:pk>/", QassobDetailView.as_view(), name="qassobs-detail"),
]
