"""Payment routes — mounted at /api/v1/payments/ from config/urls.py."""
from django.urls import path

from .cards import CardDeleteView, CardListCreateView, CardSetDefaultView, PayWithCardView
from .views import GeneratePayLinkView, WebhookView, mock_checkout_page

urlpatterns = [
    # buyer → backend: ask for a fresh pay URL for an order (legacy WebView fallback)
    path("orders/<int:order_id>/pay/", GeneratePayLinkView.as_view(), name="payments-pay-link"),
    # v3.7 in-app saved-card flow — buyer picks a card on PaymentMethodPicker, this endpoint settles
    # the order. Mock mode = instant success. Real Payme mode (future) = OTP round-trip.
    path("orders/<int:order_id>/pay-with-card/", PayWithCardView.as_view(), name="payments-pay-with-card"),
    path("cards/", CardListCreateView.as_view(), name="payments-cards"),
    path("cards/<int:pk>/", CardDeleteView.as_view(), name="payments-card-detail"),
    path("cards/<int:pk>/set-default/", CardSetDefaultView.as_view(), name="payments-card-set-default"),
    # provider → backend: payment-status callback (Payme / mock / etc.)
    path("webhook/", WebhookView.as_view(), name="payments-webhook"),
    # WebView lands here when PAYMENT_PROVIDER=mock. Returns the fake checkout HTML page.
    path("mock/<str:tx_id>/", mock_checkout_page, name="payments-mock-checkout"),
]
