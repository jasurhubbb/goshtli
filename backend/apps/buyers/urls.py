"""Buyer routes — mounted at /api/v1/buyers/ from config/urls.py."""
from django.urls import path
from .views import BuyerDashboardView, BuyerMeView, SavedAddressDetailView, SavedAddressListCreateView

urlpatterns = [
    path("me/", BuyerMeView.as_view(), name="buyer-me"),
    path("dashboard/", BuyerDashboardView.as_view(), name="buyer-dashboard"),
    # v2 Milestone E.2 — saved addresses (any authenticated user; routes share the buyers/ namespace)
    path("addresses/", SavedAddressListCreateView.as_view(), name="buyer-address-list"),
    path("addresses/<int:pk>/", SavedAddressDetailView.as_view(), name="buyer-address-detail"),
]
