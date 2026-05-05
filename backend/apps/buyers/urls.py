"""Buyer routes — mounted at /api/v1/buyers/ from config/urls.py."""
from django.urls import path
from .views import BuyerDashboardView, BuyerMeView

urlpatterns = [
    path("me/", BuyerMeView.as_view(), name="buyer-me"),
    path("dashboard/", BuyerDashboardView.as_view(), name="buyer-dashboard"),
]
