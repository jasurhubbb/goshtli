"""Accounts URL routes — mounted at /api/v1/auth/ from config/urls.py."""
from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import RegisterView, MeView

# Login + refresh come from simplejwt directly — they accept email+password (because USERNAME_FIELD='email') and return access/refresh tokens
urlpatterns = [
    path("register/", RegisterView.as_view(), name="auth-register"),  # POST  — create supplier/buyer account
    path("login/", TokenObtainPairView.as_view(), name="auth-login"),  # POST — exchange credentials for JWT pair
    path("refresh/", TokenRefreshView.as_view(), name="auth-refresh"),  # POST — exchange refresh for new access
    path("me/", MeView.as_view(), name="auth-me"),                     # GET/PATCH — current user profile
]
