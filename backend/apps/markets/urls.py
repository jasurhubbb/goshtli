"""Market routes — mounted at /api/v1/markets/. Read public; write admin-only."""
from django.urls import path
from .views import MarketDetailView, MarketListCreateView, MyMarketView

urlpatterns = [
    path("", MarketListCreateView.as_view(), name="market-list"),
    # /me/ MUST come before /<int:pk>/ — otherwise "me" would match the pk converter and 404 as int.
    path("me/", MyMarketView.as_view(), name="market-me"),
    path("<int:pk>/", MarketDetailView.as_view(), name="market-detail"),
]
