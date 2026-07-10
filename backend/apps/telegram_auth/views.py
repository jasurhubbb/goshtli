"""Telegram phone-verification views.

Three endpoints:
  • POST /api/v1/auth/telegram/start/   (app)      — normalize phone, open a verification session, return the
                                                     t.me deep-link the "Botga o'tish" button opens.
  • POST /api/v1/telegram/webhook/      (Telegram) — handle /start (greet + share-contact button) and the
                                                     shared Contact (anti-spoof, match phone, send the code).
  • POST /api/v1/auth/telegram/verify/  (app)      — check the entered code and mint JWT, reusing the exact
                                                     new_user/{access,refresh} shape the Firebase flow returned
                                                     so the buyer app's downstream (phone-register) is unchanged.

Security controls (see otp.py for the code-hashing rationale): 6-digit CSPRNG code, HMAC+pepper storage,
constant-time compare, 5-min TTL, max 5 attempts, 60s resend cooldown, 5 sends/hr per phone, single-use,
only-the-latest-code valid, anti-spoof (contact.user_id == sender.id), webhook secret-token header, and
enumeration-safe responses (identical whether or not the phone maps to an account).
"""
import hmac
import json
import logging

from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.accounts.models import User
from apps.accounts.views import _jwt_for
from . import otp, telegram_api
from .models import TelegramVerification
from .serializers import TelegramStartSerializer, TelegramVerifySerializer

log = logging.getLogger(__name__)


def _bot_deeplink(session_token: str) -> str:
    """https://t.me/<username>?start=<session_token> — the button target. Username comes from env so the
    app never hardcodes it (backend owns the bot identity)."""
    username = (getattr(settings, "TELEGRAM_BOT_USERNAME", "") or "").lstrip("@")
    return f"https://t.me/{username}?start={session_token}"


class TelegramStartView(APIView):
    """POST {phone} → {session_token, bot_url, expires_in}. Enumeration-safe: the response is identical whether
    or not the phone already has an account (we don't touch the User table here)."""
    permission_classes = (AllowAny,)
    throttle_classes = (ScopedRateThrottle,)
    throttle_scope = "telegram_start"

    def post(self, request):
        ser = TelegramStartSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        phone = otp.normalize_uz_phone(ser.validated_data["phone"])
        if not phone:
            return Response({"detail": "Telefon raqami noto'g'ri."}, status=status.HTTP_400_BAD_REQUEST)

        # Only the newest session per phone should be live. Sweep this phone's still-open (unverified) sessions
        # so a shared contact can't match a stale row and the "latest code only" rule holds.
        TelegramVerification.objects.filter(phone=phone).exclude(
            status=TelegramVerification.Status.VERIFIED).delete()

        v = TelegramVerification.objects.create(phone=phone, session_token=otp.new_session_token())
        return Response({
            "session_token": v.session_token,
            "bot_url": _bot_deeplink(v.session_token),
            "expires_in": otp.SESSION_TTL_SECONDS,
        })


class TelegramVerifyView(APIView):
    """POST {session_token, code} → JWT pair (existing user) or {phone, new_user: true} (unknown phone).
    Mirrors FirebasePhoneLoginView's response shape byte-for-byte so the client branching is unchanged."""
    permission_classes = (AllowAny,)
    throttle_classes = (ScopedRateThrottle,)
    throttle_scope = "telegram_verify"

    # One generic failure so an attacker can't distinguish "wrong code" from "expired" from "too many attempts".
    _BAD = {"detail": "Kod noto'g'ri yoki muddati o'tgan."}

    def post(self, request):
        ser = TelegramVerifySerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        token = ser.validated_data["session_token"]
        code = ser.validated_data["code"]

        try:
            v = TelegramVerification.objects.get(session_token=token)
        except TelegramVerification.DoesNotExist:
            return Response(self._BAD, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        # Must be a live, code-sent, unconsumed, unexpired session with attempts left.
        if (v.status != TelegramVerification.Status.CODE_SENT or v.consumed_at is not None
                or not v.code_expires_at or v.code_expires_at < now
                or v.attempts >= otp.MAX_VERIFY_ATTEMPTS):
            return Response(self._BAD, status=status.HTTP_400_BAD_REQUEST)

        if not otp.code_matches(v.phone, code, v.code_hash):
            # Burn an attempt; when the cap is hit the code is dead and the user must restart from the app.
            v.attempts += 1
            v.save(update_fields=("attempts", "updated_at"))
            return Response(self._BAD, status=status.HTTP_400_BAD_REQUEST)

        # Correct code — consume the session (single-use) and bridge into our JWT world.
        v.status = TelegramVerification.Status.VERIFIED
        v.consumed_at = now
        v.save(update_fields=("status", "consumed_at", "updated_at"))

        try:
            user = User.objects.get(phone=v.phone)
            if not user.is_active:
                return Response({"detail": "Hisob o'chirilgan. Qo'llab-quvvatlashga murojaat qiling."},
                                status=status.HTTP_403_FORBIDDEN)
            return Response({**_jwt_for(user), "new_user": False})
        except User.DoesNotExist:
            # Unknown phone → the app collects the name and calls /auth/phone-register/ next, exactly as before.
            return Response({"phone": v.phone, "new_user": True})


class TelegramWebhookView(APIView):
    """POST — Telegram delivers Update objects here. Secured by the secret-token header (constant-time compared),
    not by auth; couriers of forged updates are rejected with 403. Always returns 200 quickly on handled updates
    so Telegram doesn't retry."""
    permission_classes = (AllowAny,)
    authentication_classes = ()                 # no JWT — this is machine-to-machine, guarded by the secret token

    def post(self, request):
        expected = getattr(settings, "TELEGRAM_WEBHOOK_SECRET", "") or ""
        got = request.headers.get("X-Telegram-Bot-Api-Secret-Token", "")
        if not expected or not hmac.compare_digest(expected, got):
            return Response(status=status.HTTP_403_FORBIDDEN)

        try:
            update = request.data if isinstance(request.data, dict) else json.loads(request.body or b"{}")
        except (ValueError, TypeError):
            return Response({"ok": True})       # unparseable → ack so Telegram stops retrying

        message = (update or {}).get("message") or {}
        if not message:
            return Response({"ok": True})       # we only subscribe to `message`; ignore anything else

        try:
            if message.get("contact"):
                self._handle_contact(message)
            elif (message.get("text") or "").startswith("/start"):
                self._handle_start(message)
            else:
                self._reprompt(message)
        except Exception:
            # Never let a handler bug turn into a non-200 (Telegram would hammer us with retries).
            log.exception("telegram webhook handler failed")
        return Response({"ok": True})

    # ---- handlers ----

    def _handle_start(self, message: dict):
        """Greet (bilingual, by first name) and show the share-contact button. If the deep-link payload maps to
        a live session, stash the chat id on it so the contact step can correlate."""
        chat_id = message["chat"]["id"]
        first_name = (message.get("from") or {}).get("first_name") or ""
        parts = (message.get("text") or "").split(maxsplit=1)
        payload = parts[1].strip() if len(parts) > 1 else ""
        if payload:
            TelegramVerification.objects.filter(
                session_token=payload, status=TelegramVerification.Status.AWAITING_CONTACT
            ).update(telegram_chat_id=chat_id, telegram_user_id=(message.get("from") or {}).get("id"))

        text = (
            f"Salom {first_name} 👋\n"
            "@qirikki'ning rasmiy botiga xush kelibsiz\n\n"
            "⬇ Kontaktingizni yuboring (tugmani bosib)\n\n"
            "🇺🇸\n"
            f"Hi {first_name} 👋\n"
            "Welcome to @qirikki's official bot\n\n"
            "⬇ Send your contact (by clicking button)"
        )
        telegram_api.send_message(
            chat_id, text,
            reply_markup=telegram_api.contact_request_keyboard("📱 Raqamni yuborish / Share my number"))

    def _handle_contact(self, message: dict):
        """Validate the shared contact is the sender's OWN Telegram-verified number, match it to a live session,
        generate + send a code (respecting the resend cooldown + hourly cap)."""
        chat_id = message["chat"]["id"]
        sender_id = (message.get("from") or {}).get("id")
        contact = message.get("contact") or {}

        # --- anti-spoof gate ---
        # Typed numbers arrive as text (no contact object at all). A forwarded / address-book contact has a
        # missing user_id or one that belongs to someone else. Only a request_contact tap yields a contact
        # whose user_id equals the sender — that's the only case we trust as a verified phone.
        if contact.get("user_id") is None or contact.get("user_id") != sender_id:
            telegram_api.send_message(
                chat_id,
                "Iltimos, pastdagi tugma orqali o'z raqamingizni yuboring (qo'lda yozmang).\n"
                "Please use the button below to share your own number (don't type it).",
                reply_markup=telegram_api.contact_request_keyboard("📱 Raqamni yuborish / Share my number"))
            return

        phone = otp.normalize_uz_phone(contact.get("phone_number", ""))
        if not phone:
            telegram_api.send_message(chat_id, "Raqam noto'g'ri. / Invalid number.")
            return

        now = timezone.now()
        # Latest live session for this phone (the app just created it in /start/). If there's none, the user
        # opened the bot without starting from the app — tell them to start there.
        v = (TelegramVerification.objects
             .filter(phone=phone, status__in=(TelegramVerification.Status.AWAITING_CONTACT,
                                              TelegramVerification.Status.CODE_SENT))
             .filter(created_at__gte=now - timedelta(seconds=otp.SESSION_TTL_SECONDS))
             .order_by("-created_at").first())
        if v is None:
            telegram_api.send_message(
                chat_id,
                "Avval ilovada telefon raqamingizni kiriting, keyin shu yerga qayting.\n"
                "Please enter your phone in the app first, then come back here.",
                reply_markup=telegram_api.REMOVE_KEYBOARD)
            return

        # --- rate limits (per phone) ---
        recent_sends = TelegramVerification.objects.filter(
            phone=phone, code_sent_at__gte=now - timedelta(hours=1)).count()
        if recent_sends >= otp.MAX_SENDS_PER_HOUR:
            telegram_api.send_message(
                chat_id, "Juda ko'p urinish. Bir soatdan keyin qayta urinib ko'ring.\n"
                         "Too many attempts. Try again in an hour.",
                reply_markup=telegram_api.REMOVE_KEYBOARD)
            return
        if v.code_sent_at and (now - v.code_sent_at).total_seconds() < otp.RESEND_COOLDOWN_SECONDS:
            telegram_api.send_message(chat_id, "Biroz kuting. / Please wait a moment.",
                                      reply_markup=telegram_api.REMOVE_KEYBOARD)
            return

        # --- generate + persist + send ---
        code = otp.generate_code()
        v.code_hash = otp.hash_code(phone, code)
        v.attempts = 0
        v.code_sent_at = now
        v.code_expires_at = now + timedelta(seconds=otp.CODE_TTL_SECONDS)
        v.status = TelegramVerification.Status.CODE_SENT
        v.telegram_user_id = sender_id
        v.telegram_chat_id = chat_id
        v.save(update_fields=("code_hash", "attempts", "code_sent_at", "code_expires_at",
                              "status", "telegram_user_id", "telegram_chat_id", "updated_at"))

        # Message 1: the code (and drop the keyboard). Message 2: send them back to the app.
        telegram_api.send_message(chat_id, f"✅ Tasdiqlandi. Kodingiz: {code}",
                                  reply_markup=telegram_api.REMOVE_KEYBOARD)
        telegram_api.send_message(chat_id, "Ilovaga qayting va kodni kiriting 📲\n"
                                           "Go back to the app and enter the code.")

    def _reprompt(self, message: dict):
        chat_id = message["chat"]["id"]
        telegram_api.send_message(
            chat_id,
            "Raqamingizni yuborish uchun pastdagi tugmani bosing.\n"
            "Tap the button below to share your number.",
            reply_markup=telegram_api.contact_request_keyboard("📱 Raqamni yuborish / Share my number"))
