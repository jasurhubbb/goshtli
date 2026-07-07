"""Order routes — mounted at /api/v1/orders/. Buyer-side routes first, supplier-side under /supplier/."""
from django.urls import path
from .views import (MyOrdersView, OrderCancelView, OrderConfirmDeliveryView, OrderCreateView,
                    OrderDetailView, SupplierOrderStatusView, SupplierOrdersView)

urlpatterns = [
    path("", OrderCreateView.as_view(), name="order-create"),                           # POST place order
    path("my/", MyOrdersView.as_view(), name="order-my"),                                # GET buyer's history
    path("<int:pk>/", OrderDetailView.as_view(), name="order-detail"),                   # GET single order
    path("<int:pk>/cancel/", OrderCancelView.as_view(), name="order-cancel"),            # POST buyer cancellation
    # v3.9.14 — buyer confirms delivery. Separate route from cancel so intent is explicit.
    path("<int:pk>/confirm-delivery/", OrderConfirmDeliveryView.as_view(),
         name="order-confirm-delivery"),
    path("supplier/", SupplierOrdersView.as_view(), name="order-supplier-list"),         # GET supplier's incoming orders
    path("supplier/<int:pk>/status/", SupplierOrderStatusView.as_view(), name="order-supplier-status"),  # POST status update
]
