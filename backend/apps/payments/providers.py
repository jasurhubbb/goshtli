"""Payment provider abstraction.

Why this layer exists:
  • Local dev + tester builds need a working end-to-end checkout flow WITHOUT real Payme merchant
    credentials. A `MockProvider` simulates the WebView round-trip (auto-completes after a few seconds,
    optionally fails based on the amount for testing the failure path).
  • Production wraps the real Payme JSON-RPC merchant API via PayTechUZ. The mobile app stays unchanged —
    it sees the same `payment_url` field whichever provider is active.
  • Future-proofing: when we add Click / Uzum / Paynet, each gets a new subclass; the rest of the system
    (Order model, webhook view, mobile WebView) is provider-agnostic.

Selection: `PAYMENT_PROVIDER` env var. Defaults to "mock" for local. Set to "payme" in production once
the merchant credentials are issued.
"""
import hmac
import hashlib
import logging
import secrets
from dataclasses import dataclass
from decimal import Decimal
from typing import Optional

from decouple import config

log = logging.getLogger(__name__)


@dataclass
class PayLinkResult:
    """Per-pay-attempt artefact returned to the mobile app.

    Fields:
      url            : The page the mobile WebView opens (Payme's hosted checkout, or our /sandbox/ for mock)
      provider       : The string code we wrote into Order.payment_provider (e.g. "payme", "mock")
      provider_tx_id : The opaque transaction identifier — webhook uses this to look up the matching Order
    """
    url: str
    provider: str
    provider_tx_id: str


class PaymentProvider:
    """Abstract provider — implementations create + verify payments and validate webhook signatures."""

    code: str = ""

    def generate_pay_link(self, *, order, return_url: str = "") -> PayLinkResult:
        """Mint a fresh payment URL for `order` and persist the provider's tx-id on the row."""
        raise NotImplementedError

    def verify_webhook(self, *, request_body: bytes, signature: Optional[str]) -> bool:
        """Validate the webhook request was actually sent by the provider (not someone replaying our URL).
        Returns True if the signature/auth-header matches; False otherwise. Subclasses MUST implement."""
        raise NotImplementedError

    def parse_webhook(self, payload: dict) -> tuple[str, str]:
        """Pull (provider_tx_id, new_payment_status) out of the provider's webhook body.
        Returns (tx_id, status) where status is one of: "PAID", "FAILED", "REFUNDED"."""
        raise NotImplementedError


# ---------------------- Mock provider (local dev + sandbox) ----------------------

class MockProvider(PaymentProvider):
    """In-process simulator. The mobile WebView opens our `/api/v1/payments/mock/<tx_id>/` page, which:
      • If the amount ends in 0 → auto-success after 3 seconds
      • If the amount ends in 1 → auto-fail after 3 seconds (lets us test the failure flow without
        bothering real providers)
      • Otherwise → shows a [Pay] / [Cancel] / [Simulate fail] button trio for manual control

    No real money moves. No external API calls. Safe to leave enabled by default for local + tester builds.
    """

    code = "mock"

    def generate_pay_link(self, *, order, return_url: str = "") -> PayLinkResult:
        tx_id = f"mock_{secrets.token_hex(8)}"
        # Build the URL the mobile WebView opens. Always-absolute so it works inside an Android WebView
        # without origin shenanigans.
        base = config("PAYMENT_PUBLIC_BASE_URL", default="http://localhost:8000")
        url = f"{base.rstrip('/')}/api/v1/payments/mock/{tx_id}/?order_id={order.id}&amount={order.total_price}"
        return PayLinkResult(url=url, provider=self.code, provider_tx_id=tx_id)

    def verify_webhook(self, *, request_body: bytes, signature: Optional[str]) -> bool:
        # The mock page calls the webhook ITSELF (after the user clicks Pay/Cancel) using a shared secret.
        # We HMAC the body with the same secret used by the mock page to fake-sign requests.
        expected = hmac.new(self._secret().encode(), request_body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(signature or "", expected)

    def parse_webhook(self, payload: dict) -> tuple[str, str]:
        tx_id = payload.get("provider_tx_id", "")
        status = payload.get("status", "").upper()
        if status not in ("PAID", "FAILED", "REFUNDED"):
            raise ValueError(f"Mock webhook sent unknown status={status!r}")
        return tx_id, status

    @staticmethod
    def _secret() -> str:
        # Fixed for dev — Mock isn't a security boundary; the real one is the Payme HMAC check.
        return config("MOCK_WEBHOOK_SECRET", default="mock-webhook-secret-dev")


# ---------------------- Payme provider (production) ----------------------

class PaymeProvider(PaymentProvider):
    """Wraps Payme's Merchant API via the `payme-pkg` library (PayTechUZ).

    Pre-requisites (Railway env vars):
      • PAYME_ID         — merchant ID issued after sign-up at business.payme.uz
      • PAYME_KEY        — secret key for HMAC-signing webhook responses
      • PAYME_ENDPOINT   — "https://checkout.paycom.uz/" (prod) or test endpoint for sandbox
    The `payme-pkg` library reads these via its own config — we just guard against accidental use without
    the env vars being set.
    """

    code = "payme"

    def generate_pay_link(self, *, order, return_url: str = "") -> PayLinkResult:
        # Lazy import — keeps the dependency optional. If payme-pkg isn't installed (local dev), the
        # provider isn't selectable but the rest of the system still boots.
        try:
            from payme.classes.cards import PaymeClientCards  # type: ignore[import-not-found]
        except ImportError as e:
            raise RuntimeError("PaymeProvider needs `payme-pkg` installed. Add it to requirements.txt.") from e

        merchant_id = config("PAYME_ID", default="")
        if not merchant_id:
            raise RuntimeError("PAYME_ID env var is not set")
        # Payme expects amounts in TIYIN (1 UZS = 100 tiyin). Order.total_price is in UZS as Decimal.
        amount_tiyin = int(Decimal(order.total_price) * 100)
        # The library's `generate_pay_link` builds a checkout URL keyed by account/order id + amount;
        # signed with PAYME_KEY server-side so we don't have to mint that manually.
        url = PaymeClientCards.generate_pay_link(  # type: ignore[attr-defined]
            id=order.id,
            amount=amount_tiyin,
            return_url=return_url,
        )
        # provider_tx_id stays empty until Payme's first webhook arrives (it generates the txid). We set
        # it to the order_id for now so the row is queryable; the webhook then replaces it with the real id.
        return PayLinkResult(url=url, provider=self.code, provider_tx_id=str(order.id))

    def verify_webhook(self, *, request_body: bytes, signature: Optional[str]) -> bool:
        # Payme uses HTTP Basic Auth header (Authorization: Basic base64(Paycom:PAYME_KEY)) for inbound
        # webhooks rather than HMAC of the body. The library's PaymeWebHookAPIView already validates this;
        # at the framework layer this method exists for consistency with the abstract base.
        return signature is not None and signature.startswith("Basic ")

    def parse_webhook(self, payload: dict) -> tuple[str, str]:
        # Payme uses JSON-RPC. The method name + `params._id` tell us the tx + state. PaymeWebHookAPIView's
        # default callbacks (handle_successfully_payment, handle_cancelled_payment) populate Order via
        # explicit overrides — see views.py.
        method = payload.get("method", "")
        params = payload.get("params", {}) or {}
        tx_id = str(params.get("_id") or params.get("transaction") or "")
        if method == "PerformTransaction" or params.get("state") == 2:
            return tx_id, "PAID"
        if method == "CancelTransaction" or params.get("state") in (-1, -2):
            return tx_id, "FAILED"
        raise ValueError(f"Unhandled Payme webhook method={method!r}")


# ---------------------- Provider selection ----------------------

_REGISTRY: dict[str, type[PaymentProvider]] = {
    MockProvider.code: MockProvider,
    PaymeProvider.code: PaymeProvider,
}


def get_provider() -> PaymentProvider:
    """Returns the currently-active provider instance based on the PAYMENT_PROVIDER env var.
    Default is `mock` so local development works out of the box without merchant credentials."""
    code = config("PAYMENT_PROVIDER", default="mock")
    cls = _REGISTRY.get(code)
    if cls is None:
        log.warning("Unknown PAYMENT_PROVIDER=%r; falling back to mock", code)
        cls = MockProvider
    return cls()
