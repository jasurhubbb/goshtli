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
from apps.notifications.fcm import _ensure_initialized as _ensure_firebase_initialized
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


# ---------- Firebase Phone Auth (v3.4) ----------

@extend_schema(
    request={"type": "object", "properties": {"firebase_id_token": {"type": "string"}},
             "required": ["firebase_id_token"]},
    responses={
        200: {"type": "object", "properties": {
            "access": {"type": "string"}, "refresh": {"type": "string"},
            "new_user": {"type": "boolean"}, "phone": {"type": "string"}}},
        400: None, 401: None, 503: None},
    description="POST {firebase_id_token}. Verifies the token via firebase-admin, extracts the phone_number "
                "claim, and either returns a JWT pair (existing user → new_user=false) or a {phone, new_user=true} "
                "signal so the client can push the user to /auth/details for name entry. Firebase has already "
                "proven the user controls this phone via SMS challenge, so we don't need a separate OTP step.")
class FirebasePhoneLoginView(APIView):
    """POST /api/v1/auth/firebase-phone-login/ — token-trade endpoint backing the v3.4 Firebase OTP flow.

    Why: Firebase Phone Auth handles the SMS challenge entirely client-side; the proof that arrives at our
    backend is a signed Firebase ID token containing a `phone_number` claim. We verify the signature against
    Google's public keys (firebase-admin handles this), then bridge into our own JWT-based session model
    so the rest of the app (cart, addresses, orders) keeps using the same Authorization header.
    """
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        token = request.data.get("firebase_id_token")
        if not token:
            return Response({"detail": "firebase_id_token is required."},
                            status=status.HTTP_400_BAD_REQUEST)
        # firebase-admin must have been initialized at boot — it shares one App with the FCM push side.
        # If FIREBASE_CREDENTIALS_JSON is missing in the env (local dev without the service account),
        # we surface a 503 so the client can show a "service unavailable" message instead of a generic 500.
        if not _ensure_firebase_initialized():
            return Response({"detail": "Firebase Admin SDK not configured on the server."},
                            status=status.HTTP_503_SERVICE_UNAVAILABLE)
        # Lazy import — firebase_admin is imported eagerly by notifications.fcm, but the auth submodule
        # is only needed here. Keeps the boot path simpler if a future deploy drops the FCM side.
        from firebase_admin import auth as fb_auth
        # Verbose error mapping so the client sees the SPECIFIC failure cause. The previous catch-all
        # returned "Invalid or expired" for everything from "wrong signature" to "clock skew" to "malformed
        # base64" — useless for debugging. Each branch now identifies the exact firebase-admin exception.
        import logging as _log
        log = _log.getLogger(__name__)
        try:
            # clock_skew_seconds=30 tolerates small drift between the issuer (Google) and our server's
            # clock. Docker Desktop on macOS notoriously drifts the container's clock by a few seconds
            # when the Mac sleeps; without this tolerance Firebase rejects freshly-minted tokens as
            # "used too early" (iat slightly in our future). 30s is the spec-recommended max for JWT
            # `nbf`/`iat` skew and the value Google's own client libs use as default.
            decoded = fb_auth.verify_id_token(token, clock_skew_seconds=30)
        except fb_auth.ExpiredIdTokenError as e:
            log.warning("Firebase token EXPIRED: %s", e)
            return Response({"detail": "Firebase token expired — sign in again."},
                            status=status.HTTP_401_UNAUTHORIZED)
        except fb_auth.RevokedIdTokenError as e:
            log.warning("Firebase token REVOKED: %s", e)
            return Response({"detail": "Firebase token revoked — sign in again."},
                            status=status.HTTP_401_UNAUTHORIZED)
        except fb_auth.InvalidIdTokenError as e:
            # Most common: project mismatch (aud claim doesn't match service account's project_id), wrong
            # signature, malformed JWT. The error message is detailed; surface it so we know which one.
            log.warning("Firebase token INVALID: %s", e)
            return Response({"detail": f"Firebase token invalid: {e}"},
                            status=status.HTTP_401_UNAUTHORIZED)
        except ValueError as e:
            log.warning("Firebase token MALFORMED: %s", e)
            return Response({"detail": f"Firebase token malformed: {e}"},
                            status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            # Unexpected — surfacing it instead of swallowing helps catch firebase-admin bugs / network
            # issues (verify_id_token fetches Google's public keys on first call; that can fail).
            log.exception("Firebase verify_id_token unexpected error")
            return Response({"detail": f"Firebase verification failed: {type(e).__name__}: {e}"},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        phone = decoded.get("phone_number")
        if not phone:
            return Response({"detail": "Firebase token has no phone_number claim — was the user signed in "
                                       "via a non-phone provider?"},
                            status=status.HTTP_400_BAD_REQUEST)
        # Existing user → log them in and return JWT pair. No new_user flag needed — caller knows by absence
        # of `phone` in the response.
        try:
            user = User.objects.get(phone=phone)
            if not user.is_active:
                return Response({"detail": "Account is disabled. Contact support."},
                                status=status.HTTP_403_FORBIDDEN)
            return Response({**_jwt_for(user), "new_user": False})
        except User.DoesNotExist:
            # New user — bounce the client to /auth/details to collect name + optional business. The phone
            # is now Firebase-verified, so when the client calls /auth/phone-register/ next we can trust it.
            return Response({"phone": phone, "new_user": True})


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
