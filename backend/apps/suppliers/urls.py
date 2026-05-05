"""Supplier routes — mounted at /api/v1/suppliers/ from config/urls.py."""
from django.urls import path
from .views import SupplierDashboardView, SupplierMeView

urlpatterns = [
    path("me/", SupplierMeView.as_view(), name="supplier-me"),                  # GET/PATCH own profile
    path("dashboard/", SupplierDashboardView.as_view(), name="supplier-dashboard"),  # GET aggregated stats
]
