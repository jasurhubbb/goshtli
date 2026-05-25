"""Accounts URL routes — mounted at /api/v1/auth/ from config/urls.py."""
from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import (AdminUnlockView, MeView, PhoneCheckView, PhoneLoginView,
                    PhoneRegisterView, RegisterView)

# Two coexisting auth families:
#   • Email + password (legacy v2)  — /register, /login, /refresh — kept for Django Admin staff + backwards compat
#   • Phone-only (v3.2 buyer flow) — /phone-check, /phone-login, /phone-register — the primary mobile auth path
urlpatterns = [
    # Legacy email-based — kept for staff / admin tooling + email-only test fixtures
    path("register/", RegisterView.as_view(), name="auth-register"),
    path("login/", TokenObtainPairView.as_view(), name="auth-login"),
    path("refresh/", TokenRefreshView.as_view(), name="auth-refresh"),
    path("me/", MeView.as_view(), name="auth-me"),

    # v3.2 phone-based — anonymous mobile flow
    path("phone-check/", PhoneCheckView.as_view(), name="auth-phone-check"),
    path("phone-login/", PhoneLoginView.as_view(), name="auth-phone-login"),
    path("phone-register/", PhoneRegisterView.as_view(), name="auth-phone-register"),

    # v3.3 admin gate — password → admin JWT pair (auto-bootstraps bootstrap admin user on first hit)
    path("admin-unlock/", AdminUnlockView.as_view(), name="auth-admin-unlock"),
]
