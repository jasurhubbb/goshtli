"""Thin Telegram Bot API client over the stdlib (no `requests`/`httpx` dependency — the project ships neither).

Only the three methods we need: sendMessage, setWebhook, deleteWebhook. Every call is best-effort: network
failures are logged and swallowed so a Telegram hiccup never 500s the webhook (which would make Telegram retry
the same update) or the /start endpoint.
"""
import json
import logging
import urllib.error
import urllib.request

from django.conf import settings

log = logging.getLogger(__name__)

_API_ROOT = "https://api.telegram.org"


def _token() -> str:
    return getattr(settings, "TELEGRAM_BOT_TOKEN", "") or ""


def _call(method: str, payload: dict) -> dict | None:
    """POST JSON to the Bot API. Returns the parsed `result` on success, None on any failure."""
    token = _token()
    if not token:
        log.warning("telegram: TELEGRAM_BOT_TOKEN not configured; skipping %s", method)
        return None
    url = f"{_API_ROOT}/bot{token}/{method}"
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST",
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if not data.get("ok"):
                log.warning("telegram: %s returned not-ok: %s", method, data)
                return None
            return data.get("result")
    except urllib.error.HTTPError as e:
        # Surface Telegram's own error body (e.g. "chat not found", "bot was blocked") — helps debugging.
        detail = e.read().decode("utf-8", "replace") if e.fp else ""
        log.warning("telegram: %s HTTP %s: %s", method, e.code, detail)
        return None
    except Exception as e:
        log.warning("telegram: %s failed: %s", method, e)
        return None


# ---- Reply-markup builders ----

def contact_request_keyboard(button_text: str) -> dict:
    """One-tap reply keyboard with a request_contact button. Telegram sends the user's OWN Telegram-verified
    phone as a Contact when tapped — the number cannot be typed. request_contact works only in private chats."""
    return {"keyboard": [[{"text": button_text, "request_contact": True}]],
            "resize_keyboard": True, "one_time_keyboard": True}


REMOVE_KEYBOARD = {"remove_keyboard": True}


# ---- Methods ----

def send_message(chat_id: int, text: str, reply_markup: dict | None = None) -> dict | None:
    payload = {"chat_id": chat_id, "text": text}
    if reply_markup is not None:
        payload["reply_markup"] = reply_markup
    return _call("sendMessage", payload)


def set_webhook(url: str, secret_token: str) -> dict | None:
    """Point Telegram at our webhook. `secret_token` is echoed back in the X-Telegram-Bot-Api-Secret-Token
    header on every update so we can reject forged POSTs. We only care about `message` updates."""
    return _call("setWebhook", {"url": url, "secret_token": secret_token,
                                "allowed_updates": ["message"]})


def delete_webhook() -> dict | None:
    return _call("deleteWebhook", {})
