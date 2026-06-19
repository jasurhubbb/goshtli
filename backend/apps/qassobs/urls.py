"""Qassob URL routes. Mounted at /api/v1/qassobs/ from config/urls.py."""
from django.urls import path

from .views import (QassobAvailabilityView, QassobCapacityView, QassobDetailView,
                    QassobListView, QassobMeView)

urlpatterns = [
    # Owner CRUD — used by the partner-app onboarding final submit + Profil edit page
    path("me/", QassobMeView.as_view(), name="qassobs-me"),
    # Quick toggles for F1 + F8
    path("me/availability/", QassobAvailabilityView.as_view(), name="qassobs-me-availability"),
    path("me/capacity/", QassobCapacityView.as_view(), name="qassobs-me-capacity"),
    # Public discovery — buyer-app Servislar tab
    path("", QassobListView.as_view(), name="qassobs-list"),
    path("<int:pk>/", QassobDetailView.as_view(), name="qassobs-detail"),
]
