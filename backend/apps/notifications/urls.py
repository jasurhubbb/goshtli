"""Notification routes — mounted at /api/v1/notifications/."""
from django.urls import path
from .views import (NotificationListView, NotificationMarkAllReadView,
                    NotificationMarkReadView, NotificationUnreadCountView)

urlpatterns = [
    path("", NotificationListView.as_view(), name="notification-list"),                          # GET own list
    path("unread-count/", NotificationUnreadCountView.as_view(), name="notification-unread"),     # GET badge count
    path("read-all/", NotificationMarkAllReadView.as_view(), name="notification-read-all"),       # POST bulk read
    path("<int:pk>/read/", NotificationMarkReadView.as_view(), name="notification-read"),         # POST single read
]
