"""Partner cross-role URL routes. Mounted at /api/v1/partner/ from config/urls.py."""
from django.urls import path

from .views import (AcceptOrderView, AdvanceStatusView, DashboardView, EarningsView,
                    InboxView, LoyaltyView, QassobCalendarView, QuickPriceView,
                    RejectOrderView, ReviewReplyView, ReviewsInboxView,
                    SmartTipsView, SupplierAvailabilityView)


urlpatterns = [
    # Inbox + accept/reject/advance — F2
    path("inbox/", InboxView.as_view(), name="partner-inbox"),
    path("orders/<int:order_id>/accept/", AcceptOrderView.as_view(), name="partner-order-accept"),
    path("orders/<int:order_id>/reject/", RejectOrderView.as_view(), name="partner-order-reject"),
    path("orders/<int:order_id>/status/", AdvanceStatusView.as_view(), name="partner-order-status"),

    # Dashboard + earnings — F3
    path("dashboard/", DashboardView.as_view(), name="partner-dashboard"),
    path("earnings/", EarningsView.as_view(), name="partner-earnings"),

    # Capacity calendar — F8
    path("qassob/calendar/", QassobCalendarView.as_view(), name="partner-qassob-calendar"),

    # Reviews inbox + reply — F6
    path("reviews/incoming/", ReviewsInboxView.as_view(), name="partner-reviews-incoming"),
    path("reviews/<int:review_id>/reply/", ReviewReplyView.as_view(), name="partner-review-reply"),

    # F11 + F12
    path("loyalty/", LoyaltyView.as_view(), name="partner-loyalty"),
    path("smart-tips/", SmartTipsView.as_view(), name="partner-smart-tips"),

    # F5 quick price + F1 supplier availability (qassob availability is in apps.qassobs.urls)
    path("listings/<int:listing_id>/quick-price/", QuickPriceView.as_view(), name="partner-quick-price"),
    path("suppliers/me/availability/", SupplierAvailabilityView.as_view(), name="partner-supplier-availability"),
]
