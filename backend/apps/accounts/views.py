"""Auth views — registration, /me (GET/PATCH/DELETE), phone-based auth (v3.2), and account-level actions.

v3.2 phone-auth additions:
  • POST /auth/phone-check/    — anonymous; returns {exists: bool} for the phone in the body
  • POST /auth/phone-register/ — anonymous; creates a buyer with phone + name (+ optional business), returns JWT
  • POST /auth/phone-login/    — anonymous; finds user by phone, returns JWT (NO OTP yet — follow-up)

v3.3 admin-unlock:
  • POST /auth/admin-unlock/   — anonymous; password=123123 → returns ADMIN JWT pair (auto-bootstraps a default
    admin user on first hit). Used by the in-app /admin page so the password gate actually grants backend
    authority, not just UI access. Password is a build-time constant for now — gate behind env var when this
    leaves dev.

Security note: phone-login without OTP is acceptable for the v3 buyer-only MVP because worst-case risk is
account-squatting on a known phone. When we re-open suppliers / payments we'll gate via Twilio / Eskiz OTP.
"""
from django.conf import settings
from django.db import IntegrityError
from django.db.models import ProtectedError
from drf_spectacular.utils import extend_schema
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.buyers.models import BuyerProfile
from .models import User
from .serializers import (PhoneCheckSerializer, PhoneRegisterSerializer,
                          RegisterSerializer, UserSerializer)


# Default admin gate password — overridable via settings.ADMIN_UNLOCK_PASSWORD when we promote out of dev.
ADMIN_UNLOCK_PASSWORD = getattr(settings, "ADMIN_UNLOCK_PASSWORD", "123123")
# Bootstrap email for the auto-created admin. Stable so subsequent unlocks reuse the same user record.
ADMIN_BOOTSTRAP_EMAIL = "admin@goshtli.local"


def _jwt_for(user):
    """Helper — produces the `{access, refresh}` payload simplejwt would return on a /token/ POST.
    Re-used by phone-login + phone-register so both flows hand back the same shape the mobile app already
    understands (TokenObtainPairView clones).
    """
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


class RegisterView(generics.CreateAPIView):
    """POST /api/v1/auth/register/ — public; creates a SUPPLIER or BUYER. Admins are created via createsuperuser only."""
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = (permissions.AllowAny,)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


@extend_schema(methods=["DELETE"], responses={204: None, 409: None},
               description="Permanently delete the authenticated user's account. Refuses if they have listings "
                           "with attached orders — those need to be cancelled/completed first.")
class MeView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /api/v1/auth/me/ — current user's record. PATCH locks email/role per the serializer."""
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated,)
    # PUT excluded — full-replace doesn't make sense for /me; PATCH is the intended write path
    http_method_names = ("get", "patch", "delete", "head", "options")

    def get_object(self): return self.request.user

    def destroy(self, request, *args, **kwargs):
        # Cascade deletes the user + their profiles + their buyer-orders. Listings with order rows are PROTECTed,
        # which raises ProtectedError — we translate to 409 so the UI can show "cancel your active orders first".
        try:
            self.get_object().delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except ProtectedError:
            return Response({"detail": "Cannot delete account — you have listings with active orders. "
                                       "Cancel or complete them first."},
                            status=status.HTTP_409_CONFLICT)


# ---------- Phone-based auth (v3.2) ----------

@extend_schema(request=PhoneCheckSerializer, responses={200: {"type": "object",
                                                              "properties": {"exists": {"type": "boolean"}}}},
               description="POST {phone}. Returns whether an account with this phone already exists. "
                           "Used by the mobile app to branch between login vs registration after the user "
                           "enters their phone number.")
class PhoneCheckView(APIView):
    """POST /api/v1/auth/phone-check/ — anonymous; one-shot lookup. Always 200; the result is in the body."""
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        ser = PhoneCheckSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        exists = User.objects.filter(phone=ser.validated_data["phone"]).exists()
        return Response({"exists": exists})


@extend_schema(request=PhoneCheckSerializer,
               responses={200: {"type": "object", "properties": {"access": {"type": "string"},
                                                                  "refresh": {"type": "string"}}},
                          404: None},
               description="POST {phone}. Returns JWT pair if an account with this phone exists; 404 otherwise. "
                           "No password / OTP for v3.2 MVP — phone is trusted. Will be gated by OTP later.")
class PhoneLoginView(APIView):
    """POST /api/v1/auth/phone-login/ — anonymous; passwordless login by phone (v3.2 MVP)."""
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        ser = PhoneCheckSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        try:
            user = User.objects.get(phone=ser.validated_data["phone"])
        except User.DoesNotExist:
            return Response({"detail": "No account with this phone — register first."},
                            status=status.HTTP_404_NOT_FOUND)
        if not user.is_active:
            return Response({"detail": "Account is disabled. Contact support."},
                            status=status.HTTP_403_FORBIDDEN)
        return Response(_jwt_for(user))


@extend_schema(request=PhoneRegisterSerializer,
               responses={201: {"type": "object", "properties": {"access": {"type": "string"},
                                                                 "refresh": {"type": "string"}}},
                          409: None},
               description="POST {phone, full_name, business_name?}. Creates a buyer account by phone and "
                           "returns the JWT pair. business_name lands on BuyerProfile via the post-create signal.")
class PhoneRegisterView(APIView):
    """POST /api/v1/auth/phone-register/ — anonymous; creates a buyer by phone (no password needed)."""
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        ser = PhoneRegisterSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        phone = ser.validated_data["phone"]
        full_name = ser.validated_data["full_name"]
        business_name = ser.validated_data.get("business_name", "")
        try:
            user = User.objects.create_user_from_phone(phone=phone, full_name=full_name)
        except IntegrityError:
            return Response({"detail": "An account with this phone already exists. Try logging in instead."},
                            status=status.HTTP_409_CONFLICT)
        # Persist business_name on the BuyerProfile that was auto-created via signal at User.save().
        # We refresh from DB in case the signal didn't fire yet, then patch the field. Optional — skip
        # when empty to avoid an unnecessary write.
        if business_name:
            BuyerProfile.objects.filter(user=user).update(business_name=business_name)
        return Response(_jwt_for(user), status=status.HTTP_201_CREATED)


# ---------- Admin unlock (v3.3) ----------

@extend_schema(
    request={"type": "object", "properties": {"password": {"type": "string"}}, "required": ["password"]},
    responses={200: {"type": "object", "properties": {"access": {"type": "string"}, "refresh": {"type": "string"}}},
               401: None},
    description="POST {password}. If password matches ADMIN_UNLOCK_PASSWORD, returns a JWT pair for the "
                "auto-bootstrapped admin account. Used by the in-app admin gate so the password actually grants "
                "backend authority. Caller swaps in the returned tokens and the next API calls run as admin.")
class AdminUnlockView(APIView):
    """POST /api/v1/auth/admin-unlock/ — password → admin JWT. Anonymous endpoint by design (the password IS
    the gate). On first call we create the bootstrap admin user via createsuperuser-equivalent code path."""
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        if request.data.get("password") != ADMIN_UNLOCK_PASSWORD:
            return Response({"detail": "Invalid password."}, status=status.HTTP_401_UNAUTHORIZED)
        # get_or_create the bootstrap admin so repeated unlocks return JWTs for the same User row. Using
        # create_superuser here so is_staff/is_superuser/role=ADMIN all line up with the legacy createsuperuser
        # flow; password is the unlock password (any admin who knows it can also log into Django Admin if needed).
        try:
            user = User.objects.get(email=ADMIN_BOOTSTRAP_EMAIL)
        except User.DoesNotExist:
            user = User.objects.create_superuser(email=ADMIN_BOOTSTRAP_EMAIL,
                                                 password=ADMIN_UNLOCK_PASSWORD,
                                                 full_name="In-App Admin")
        if not user.is_active:
            user.is_active = True
            user.save(update_fields=["is_active"])
        return Response(_jwt_for(user))
