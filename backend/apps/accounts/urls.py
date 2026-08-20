"""Accounts URL routes — mounted at /api/v1/auth/ from config/urls.py."""
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (AdminProvisionPartnerView, AdminUnlockView, BuyerTokenObtainPairView,
                    FirebasePhoneLoginView, MeView, PhoneCheckView, PhoneLoginView,
                    PhonePasswordLoginView, PhoneRegisterView, RegisterView)

# Two coexisting auth families:
#   • Email + password (legacy v2) — /register, /login, /refresh — buyer-only compatibility flow
#   • Phone-only (v3.2 buyer flow) — /phone-check, /phone-login, /phone-register — the primary mobile auth path
urlpatterns = [
    # Legacy email-based buyer flow. Admins use admin-unlock; work roles use phone-password-login.
    path("register/", RegisterView.as_view(), name="auth-register"),
    path("login/", BuyerTokenObtainPairView.as_view(), name="auth-login"),
    path("refresh/", TokenRefreshView.as_view(), name="auth-refresh"),
    path("me/", MeView.as_view(), name="auth-me"),

    # v3.2 phone-based — anonymous mobile flow
    path("phone-check/", PhoneCheckView.as_view(), name="auth-phone-check"),
    path("phone-login/", PhoneLoginView.as_view(), name="auth-phone-login"),
    path("phone-register/", PhoneRegisterView.as_view(), name="auth-phone-register"),

    # v3.9.16 — partner credential login (admin-issued phone + password) for supplier / qassob / courier,
    # and the admin-only provisioning endpoint that mints those accounts (mirrors couriers/admin/provision/).
    path("phone-password-login/", PhonePasswordLoginView.as_view(), name="auth-phone-password-login"),
    path("admin/provision-partner/", AdminProvisionPartnerView.as_view(), name="auth-provision-partner"),

    # v3.3 admin gate — password → admin JWT pair (auto-bootstraps bootstrap admin user on first hit)
    path("admin-unlock/", AdminUnlockView.as_view(), name="auth-admin-unlock"),

    # v3.4 Firebase Phone Auth — client does the OTP via Firebase, posts the resulting ID token here;
    # backend verifies + bridges into our JWT system. Replaces the OTP-less phone-login as the primary path.
    path("firebase-phone-login/", FirebasePhoneLoginView.as_view(), name="auth-firebase-phone-login"),
]
