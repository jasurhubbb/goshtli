"""Payment endpoints:
  • POST /api/v1/payments/orders/<order_id>/pay/  — buyer-only; generates a fresh pay URL for their order
  • POST /api/v1/payments/webhook/               — provider-only; updates payment_status from the callback
  • GET  /api/v1/payments/mock/<tx_id>/          — sandbox-only; renders a fake checkout page when running
                                                   with PAYMENT_PROVIDER=mock so the WebView has something
                                                   to render against during local dev
"""
import hmac
import hashlib
import json
import logging

from django.http import HttpResponse, HttpResponseBadRequest
from django.shortcuts import get_object_or_404
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.orders.models import Order
from .providers import MockProvider, get_provider

log = logging.getLogger(__name__)


class GeneratePayLinkView(APIView):
    """POST /payments/orders/<order_id>/pay/  — buyer-only.

    Idempotent in spirit: if payment_status is already PAID, returns 409 (don't double-charge). If a
    previous attempt is PENDING, regenerate a fresh URL (provider URLs expire) and reuse the same tx_id.
    On failed prior attempts, allow retry — new URL, new tx_id.
    """
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, order_id: int):
        order = get_object_or_404(Order, pk=order_id, buyer=request.user)
        if order.payment_status == Order.PaymentStatus.PAID:
            return Response({"detail": "Order is already paid."}, status=status.HTTP_409_CONFLICT)
        provider = get_provider()
        result = provider.generate_pay_link(order=order, return_url=request.data.get("return_url", ""))
        order.payment_status = Order.PaymentStatus.PENDING
        order.payment_provider = result.provider
        order.payment_provider_tx_id = result.provider_tx_id
        order.payment_url = result.url
        order.save(update_fields=["payment_status", "payment_provider", "payment_provider_tx_id",
                                  "payment_url", "updated_at"])
        return Response({
            "order_id": order.id,
            "payment_url": result.url,
            "provider": result.provider,
            "provider_tx_id": result.provider_tx_id,
            "payment_status": order.payment_status,
        })


class WebhookView(APIView):
    """POST /payments/webhook/  — provider → backend.

    Validates the request signature against the active provider, looks up the matching Order via
    payment_provider_tx_id, transitions payment_status. Always returns 200 if processing succeeded
    (some providers, like Payme, retry on non-2xx — we don't want to receive the same callback forever).
    """
    permission_classes = (permissions.AllowAny,)
    authentication_classes = ()

    def post(self, request):
        provider = get_provider()
        # We need the raw body for HMAC verification — DRF parses JSON before reaching here, so we re-read.
        raw_body = request.body
        signature_header = (request.META.get("HTTP_AUTHORIZATION") or
                            request.META.get("HTTP_X_SIGNATURE") or
                            request.META.get("HTTP_X_PAYME_SIGNATURE") or "")
        if not provider.verify_webhook(request_body=raw_body, signature=signature_header):
            log.warning("Payment webhook signature mismatch; provider=%s", provider.code)
            return Response({"error": "signature mismatch"}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            payload = json.loads(raw_body.decode())
        except Exception:
            return Response({"error": "invalid JSON"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            tx_id, new_status = provider.parse_webhook(payload)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(payment_provider_tx_id=tx_id, payment_provider=provider.code)
        except Order.DoesNotExist:
            log.warning("Webhook for unknown tx_id=%s provider=%s", tx_id, provider.code)
            return Response({"error": "order not found"}, status=status.HTTP_404_NOT_FOUND)

        # Idempotent: don't move backwards. Once PAID, stay PAID. Once FAILED, allow re-attempts but
        # don't let a stray webhook flip PAID → FAILED.
        if order.payment_status == Order.PaymentStatus.PAID:
            return Response({"ok": True, "noop": True})
        order.payment_status = getattr(Order.PaymentStatus, new_status)
        order.save(update_fields=["payment_status", "updated_at"])
        log.info("Order %s payment → %s via %s tx=%s", order.id, new_status, provider.code, tx_id)
        return Response({"ok": True})


# ---------------------- Mock sandbox page ----------------------

@csrf_exempt
@require_http_methods(["GET"])
def mock_checkout_page(request, tx_id: str):
    """Returns an HTML page the mobile WebView opens during local dev.

    Auto-behaviour driven by the amount's last digit (lets us script success/failure scenarios in tests):
      • last digit 0 → auto-success after 3 seconds
      • last digit 1 → auto-fail after 3 seconds
      • anything else → manual [Pay] / [Cancel] / [Force fail] buttons

    All three actions hit our own webhook endpoint with the mock provider's HMAC signature.
    """
    order_id = request.GET.get("order_id", "")
    amount = request.GET.get("amount", "0")
    try:
        last_digit = int(amount[-1])
    except (ValueError, IndexError):
        last_digit = 9                                          # treat malformed amount as manual
    auto_action = "PAID" if last_digit == 0 else ("FAILED" if last_digit == 1 else "")

    # Pre-compute the webhook URL + signed bodies for each action so the in-page JS can call them without
    # leaking the secret to the WebView (the secret is baked into the signature ONLY).
    actions = {}
    for action in ("PAID", "FAILED"):
        body = json.dumps({"provider_tx_id": tx_id, "status": action})
        sig = hmac.new(MockProvider._secret().encode(), body.encode(), hashlib.sha256).hexdigest()
        actions[action] = {"body": body, "sig": sig}

    html = f"""<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Mock checkout</title>
<style>
  body {{ font-family: -apple-system, system-ui, sans-serif; padding: 40px 24px; max-width: 480px;
          margin: 0 auto; color: #1c1b1f; background: #fef7ff; }}
  h1 {{ font-size: 28px; margin-bottom: 8px; }}
  .meta {{ color: #79747e; font-size: 14px; margin-bottom: 28px; }}
  .row {{ background: white; border-radius: 16px; padding: 16px; margin: 10px 0; }}
  .row b {{ display: block; color: #79747e; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; }}
  .row span {{ font-size: 18px; font-weight: 600; }}
  button {{ width: 100%; padding: 16px; border-radius: 12px; border: none; font-size: 16px;
            font-weight: 600; cursor: pointer; margin-top: 10px; }}
  .pay {{ background: #6750a4; color: white; }}
  .cancel {{ background: #f4eff4; color: #1c1b1f; }}
  .fail {{ background: #b3261e; color: white; }}
  #status {{ text-align: center; padding: 14px; border-radius: 12px; margin-top: 20px; }}
  #status.ok {{ background: #d3eed3; color: #1f5e1f; }}
  #status.bad {{ background: #f9dedc; color: #8c1d18; }}
  .badge {{ background: #ffe0b2; color: #5d3a00; padding: 4px 10px; border-radius: 999px;
            font-size: 11px; display: inline-block; margin-bottom: 16px; font-weight: 700; }}
</style>
</head><body>
<div class="badge">MOCK · NO REAL PAYMENT</div>
<h1>Buyurtmangiz uchun to'lov</h1>
<div class="meta">Bu sandbox sahifa — haqiqiy karta o'tkazilmaydi.</div>
<div class="row"><b>Buyurtma</b><span>#{order_id}</span></div>
<div class="row"><b>Summa</b><span>{amount} so'm</span></div>

<button class="pay" onclick="send('PAID')">To'lash (test card)</button>
<button class="fail" onclick="send('FAILED')">Force fail</button>
<button class="cancel" onclick="history.back()">Bekor qilish</button>

<div id="status" style="display:none"></div>

<script>
  const actions = {json.dumps(actions)};
  const autoAction = "{auto_action}";

  async function send(action) {{
    const a = actions[action];
    const r = await fetch('/api/v1/payments/webhook/', {{
      method: 'POST',
      headers: {{
        'Content-Type': 'application/json',
        'X-Signature': a.sig,
      }},
      body: a.body,
    }});
    const ok = r.ok;
    const s = document.getElementById('status');
    s.style.display = 'block';
    s.className = ok ? 'ok' : 'bad';
    s.textContent = ok ? (action === 'PAID' ? 'To\\'lov muvaffaqiyatli' : 'To\\'lov bekor qilindi')
                       : ('Xato: HTTP ' + r.status);
    if (ok && action === 'PAID') {{
      // Close-flag for the WebView. The mobile app polls Order.payment_status separately, so this is
      // just a courtesy — it lets the WebView dismiss itself if it cares to listen for navigation.
      setTimeout(() => location.href = 'goshtbozori://payment-success', 800);
    }}
  }}

  // Auto-action when triggered by the amount-suffix scenarios.
  if (autoAction) setTimeout(() => send(autoAction), 3000);
</script>
</body></html>"""
    return HttpResponse(html)
