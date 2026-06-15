"""Card-management endpoints + the in-app pay-with-saved-card flow.

These are the surfaces the mobile app hits AFTER the buyer has picked their delivery options and is
ready to pay. The flow:

    Delivery page  ──tap "To'lash"──>  PaymentMethodPicker (mobile)
                                              │
                                              ├── show cards from GET /payments/cards/
                                              ├── tap card → POST /payments/orders/<id>/pay-with-card/
                                              ├── tap "Yangi karta" → AddCardSheet → POST /payments/cards/
                                              ▼
                                     order.payment_status = PAID, navigate to /orders/<id>

Mock mode (PAYMENT_PROVIDER=mock — the default for local dev + tester builds) skips the SMS-OTP step
entirely. The "Pay" call returns 200 with `payment_status=PAID` immediately. Mobile shows a success
screen and pushes /orders/<id>. When PAYMENT_PROVIDER=payme is wired later, this same endpoint
generates a Payme OTP request and the mobile flow adds a 6-digit input — the rest stays unchanged.
"""
from datetime import datetime, timezone as dt_timezone
import re

from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.orders.models import Order
from .models import Card


# ---------------- Brand detection ----------------

# BIN ranges per scheme — checked in this order; first match wins. UZ-issued cards (HUMO/UZCARD) sit
# above the international schemes so they don't get misclassified when a prefix overlaps.
_BIN_PATTERNS: list[tuple[str, str]] = [
    (Card.Brand.HUMO,       r"^(9860|6440)"),
    (Card.Brand.UZCARD,     r"^(8600|5614)"),
    (Card.Brand.VISA,       r"^4"),
    (Card.Brand.MASTERCARD, r"^(5[1-5]|2[2-7])"),
]


def detect_brand(pan_digits: str) -> str:
    """Map a stripped PAN to one of Card.Brand. Returns UNKNOWN when no prefix matches."""
    for brand, pattern in _BIN_PATTERNS:
        if re.match(pattern, pan_digits):
            return brand
    return Card.Brand.UNKNOWN


# ---------------- Card add — write-only PAN ----------------

class _CardCreateSerializer(serializers.Serializer):
    """Accepts a full PAN + CVC at the API edge ONLY; neither value is ever persisted. We derive last_4
    and brand here and discard the rest. The mobile app sends:
        pan        — 13-19 digits, optionally space-separated
        expires_mm — 1-12
        expires_yy — 2- OR 4-digit year ("26" or "2026" — we normalize)
        cvc        — 3 digits (validated for format only, not retained)
        holder_name + phone_for_sms — display + future-Payme-OTP routing
    """
    pan = serializers.CharField(max_length=23, write_only=True)
    expires_mm = serializers.IntegerField(min_value=1, max_value=12)
    expires_yy = serializers.IntegerField(min_value=24, max_value=2099)
    # CVC is OPTIONAL — Uzbek-issued HUMO + UZCARD don't use a CVC at all (they verify with SMS only on
    # Payme's hosted page). VISA / MASTERCARD do use it. We still validate the FORMAT when present
    # (3-4 digits), but never persist the value. The mobile add-sheet hides the field client-side when
    # the BIN resolves to HUMO/UZCARD, so it never sends one for those brands.
    cvc = serializers.RegexField(r"^\d{3,4}$", max_length=4, write_only=True,
                                 required=False, allow_blank=True, default="")
    holder_name = serializers.CharField(max_length=80, required=False, allow_blank=True, default="")
    phone_for_sms = serializers.CharField(max_length=20, required=False, allow_blank=True, default="")
    make_default = serializers.BooleanField(required=False, default=False)

    def validate_pan(self, v: str) -> str:
        """Strip spaces, validate digit-only + length, but don't store the result. We return a flag-set
        string the create() step can split into (last_4, brand)."""
        digits = re.sub(r"\D", "", v)
        if not 12 <= len(digits) <= 19:
            raise serializers.ValidationError("PAN must be 12-19 digits.")
        return digits

    def validate(self, attrs):
        # Normalize 2-digit year to 4-digit ("26" → "2026"). PRs by the buyer's mobile-keyboard era.
        yy = attrs["expires_yy"]
        attrs["expires_yy"] = yy if yy >= 100 else 2000 + yy
        return attrs


class _CardReadSerializer(serializers.ModelSerializer):
    """The shape returned by every cards endpoint. Read-only by design — there's no PATCH on cards;
    `set-default` is its own endpoint, and changing PAN/expiry means adding a new card."""
    class Meta:
        model = Card
        fields = ("id", "last_4", "brand", "expires_month", "expires_year",
                  "holder_name", "phone_for_sms", "is_default", "created_at")
        read_only_fields = fields


class CardListCreateView(generics.GenericAPIView):
    """GET /payments/cards/ — list the buyer's saved cards (default first, then newest).
    POST /payments/cards/ — add a card; PAN/CVC are write-only, only last_4 + brand persist.

    First card added is auto-default. Subsequent cards default to is_default=False unless `make_default`
    was passed; the buyer manages this via the set-default endpoint or by tapping the card on the picker.
    """
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = _CardReadSerializer

    def get(self, request):
        qs = Card.objects.filter(user=request.user)
        return Response(_CardReadSerializer(qs, many=True).data)

    def post(self, request):
        s = _CardCreateSerializer(data=request.data); s.is_valid(raise_exception=True)
        d = s.validated_data
        digits = d["pan"]
        # Single-source-of-truth: every persistence path derives these two from the digits.
        card_kwargs = {
            "user": request.user,
            "last_4": digits[-4:],
            "brand": detect_brand(digits),
            "expires_month": d["expires_mm"],
            "expires_year": d["expires_yy"],
            "holder_name": d.get("holder_name", ""),
            "phone_for_sms": d.get("phone_for_sms", ""),
        }
        # Auto-default the FIRST card so the picker has something to start with. Subsequent cards stay
        # non-default unless the buyer explicitly opts in via `make_default` or the set-default endpoint.
        had_cards = Card.objects.filter(user=request.user).exists()
        if not had_cards or d.get("make_default", False):
            card_kwargs["is_default"] = True
            # If make_default was set on a user that already has another default, clear it first.
            Card.objects.filter(user=request.user, is_default=True).update(is_default=False)
        card = Card.objects.create(**card_kwargs)
        return Response(_CardReadSerializer(card).data, status=status.HTTP_201_CREATED)


class CardDeleteView(generics.DestroyAPIView):
    """DELETE /payments/cards/<id>/ — only the card's owner can remove it. Deleting the default card
    leaves the user without a default; the picker shows "Yangi karta" front-and-center until they add one."""
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = _CardReadSerializer

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Card.objects.none()
        return Card.objects.filter(user=self.request.user)


class CardSetDefaultView(APIView):
    """POST /payments/cards/<id>/set-default/ — atomically promote a card to default. Returns the
    full card list so the mobile picker can refresh in one round-trip."""
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, pk: int):
        card = get_object_or_404(Card, pk=pk, user=request.user)
        card.make_default()
        cards = Card.objects.filter(user=request.user)
        return Response(_CardReadSerializer(cards, many=True).data)


# ---------------- Pay with saved card ----------------

class _PayWithCardSerializer(serializers.Serializer):
    """Picker → backend payload. `card_id` is the saved card the buyer tapped. `sms_code` is accepted
    here for forward-compatibility with real-Payme mode; mock mode ignores it (any value, even empty,
    succeeds). The mobile picker can collect it or skip the input entirely."""
    card_id = serializers.IntegerField(min_value=1)
    sms_code = serializers.CharField(max_length=10, required=False, allow_blank=True, default="")


class PayWithCardView(APIView):
    """POST /payments/orders/<order_id>/pay-with-card/ — buyer-only.

    Mock mode (default): instantly mark the order PAID and return success. No SMS sent, no provider
    round-trip, no money moved. Lets dev + tester builds run the full Cart → Delivery → Pay → Orders
    chain end-to-end without merchant credentials.

    Real Payme mode (PAYMENT_PROVIDER=payme): would call Payme's `cards.create_p2p` + `receipts.pay`
    on the saved card token. The mobile contract stays the same — only this view's body changes.
    """
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, order_id: int):
        order = get_object_or_404(Order, pk=order_id, buyer=request.user)
        if order.payment_status == Order.PaymentStatus.PAID:
            return Response({"detail": "Order is already paid."}, status=status.HTTP_409_CONFLICT)
        s = _PayWithCardSerializer(data=request.data); s.is_valid(raise_exception=True)
        card = get_object_or_404(Card, pk=s.validated_data["card_id"], user=request.user)
        if card.is_expired:
            return Response({"detail": "Card is expired."}, status=status.HTTP_400_BAD_REQUEST)

        # Mock mode: accept the payment immediately. Real-Payme branches would go here.
        order.payment_status = Order.PaymentStatus.PAID
        order.payment_provider = "mock"
        order.payment_provider_tx_id = f"mock_card_{order.id}_{int(datetime.now(dt_timezone.utc).timestamp())}"
        order.payment_url = ""                                          # no WebView needed
        order.save(update_fields=["payment_status", "payment_provider",
                                  "payment_provider_tx_id", "payment_url", "updated_at"])
        return Response({
            "order_id": order.id,
            "payment_status": order.payment_status,
            "card_last_4": card.last_4,
            "card_brand": card.brand,
        })
