"""Courier routes — mounted at /api/v1/couriers/ from config/urls.py."""
from django.urls import path

from .views import (AdminProvisionCourierView, CourierAvailabilityView,
                    CourierDashboardView, CourierDeliveryDetailView,
                    CourierDeliveryProofView, CourierDeliveryStatusView,
                    CourierEarningsView, CourierMeView, CourierQueueView)


urlpatterns = [
    # Owner CRUD + quick toggles
    path("me/", CourierMeView.as_view(), name="courier-me"),
    path("me/availability/", CourierAvailabilityView.as_view(), name="courier-me-availability"),
    path("me/dashboard/", CourierDashboardView.as_view(), name="courier-me-dashboard"),
    path("me/earnings/", CourierEarningsView.as_view(), name="courier-me-earnings"),
    # Deliveries — list (bucket-filtered) + detail + status advance + proof upload
    path("me/deliveries/", CourierQueueView.as_view(), name="courier-me-deliveries"),
    path("me/deliveries/<int:pk>/", CourierDeliveryDetailView.as_view(), name="courier-me-delivery-detail"),
    path("me/deliveries/<int:pk>/status/", CourierDeliveryStatusView.as_view(), name="courier-me-delivery-status"),
    path("me/deliveries/<int:pk>/proof/", CourierDeliveryProofView.as_view(), name="courier-me-delivery-proof"),
    # Admin provisioning — creates a role=COURIER account with a system-generated password
    path("admin/provision/", AdminProvisionCourierView.as_view(), name="courier-admin-provision"),
]
