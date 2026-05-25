"""Supplier routes — mounted at /api/v1/suppliers/ from config/urls.py.
v3.3 adds /list/ (admin browse all) and /<pk>/ (admin edit any) for the in-app admin page."""
from django.urls import path
from .views import (SupplierAdminDetailView, SupplierDashboardView, SupplierListView,
                    SupplierMeView)

urlpatterns = [
    path("me/", SupplierMeView.as_view(), name="supplier-me"),                  # GET/PATCH own profile
    path("dashboard/", SupplierDashboardView.as_view(), name="supplier-dashboard"),  # GET aggregated stats
    # v3.3 admin endpoints — listing pickers + per-supplier admin edit
    path("list/", SupplierListView.as_view(), name="supplier-list"),            # GET (admin) all suppliers
    path("<int:pk>/", SupplierAdminDetailView.as_view(), name="supplier-detail"),  # GET/PATCH (admin) any supplier
]
