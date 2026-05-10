"""Review routes — mounted at /api/v1/reviews/."""
from django.urls import path
from .views import ReviewListCreateView, SupplierRatingView

urlpatterns = [
    path("", ReviewListCreateView.as_view(), name="review-list"),                                # GET list / POST create
    path("supplier/<int:supplier_id>/aggregate/", SupplierRatingView.as_view(), name="review-supplier-aggregate"),
]
