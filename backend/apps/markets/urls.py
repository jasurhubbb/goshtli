"""Market routes — mounted at /api/v1/markets/. Read public; write admin-only."""
from django.urls import path
from .views import MarketDetailView, MarketListCreateView

urlpatterns = [
    path("", MarketListCreateView.as_view(), name="market-list"),
    path("<int:pk>/", MarketDetailView.as_view(), name="market-detail"),
]
