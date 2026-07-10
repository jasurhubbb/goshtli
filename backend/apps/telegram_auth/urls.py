"""Telegram auth routes. Mounted at /api/v1/ from config/urls.py so the paths read naturally:
  POST /api/v1/auth/telegram/start/    (app)
  POST /api/v1/auth/telegram/verify/   (app)
  POST /api/v1/telegram/webhook/       (Telegram → us)
"""
from django.urls import path

from .views import TelegramStartView, TelegramVerifyView, TelegramWebhookView

urlpatterns = [
    path("auth/telegram/start/", TelegramStartView.as_view(), name="telegram-start"),
    path("auth/telegram/verify/", TelegramVerifyView.as_view(), name="telegram-verify"),
    path("telegram/webhook/", TelegramWebhookView.as_view(), name="telegram-webhook"),
]
