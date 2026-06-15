"""Delivery endpoints. Mounted at /api/v1/delivery/ from config/urls.py."""
from django.urls import path
from .views import DeliveryQuoteView


urlpatterns = [
    path("quote/", DeliveryQuoteView.as_view(), name="delivery-quote"),
]
