"""Thin Firebase wrapper — lazy-initialized, shared between FCM push (this app) and v3.4 Firebase Phone Auth
token verification (apps.accounts.views.FirebasePhoneLoginView). Never raises into business logic.

Credentials are loaded from one of two env vars, in priority order:
  1. FIREBASE_CREDENTIALS_JSON — the full service-account JSON pasted as a single-line env value. Used by
     Railway / Render / Docker prod, where setting one fat env var beats committing/mounting a file.
  2. FIREBASE_CREDENTIALS_FILE — path (absolute, or relative to backend/) to a downloaded JSON file. Used
     in local dev — easier to drop a Firebase-generated file into the repo (gitignored) than to wrestle a
     multi-line JSON into .env preserving the literal `\\n` chars inside `private_key`.

If neither is set, push is silently disabled and the Firebase-phone-login endpoint returns 503.
"""
import json
import logging
from pathlib import Path
from typing import Iterable

import firebase_admin
from decouple import config
from django.conf import settings
from firebase_admin import credentials, messaging

from .models import DeviceToken

log = logging.getLogger(__name__)


_app: firebase_admin.App | None = None


def _ensure_initialized() -> bool:
    """Idempotent init from FIREBASE_CREDENTIALS_JSON or FIREBASE_CREDENTIALS_FILE.
    Returns False if Firebase Admin is not configured (no creds) so the caller can degrade gracefully.

    IMPORTANT: we use python-decouple's `config()` (not `os.environ.get()`) so the values are read from the
    backend/.env file in local dev. Railway/production set env vars at the OS level — `config()` falls back
    to os.environ when the .env file doesn't list the key, so both paths work."""
    global _app
    if _app is not None: return True
    # Priority 1: inline JSON (production path — Railway sets the var at OS-level)
    raw = config("FIREBASE_CREDENTIALS_JSON", default="")
    cred = None
    if raw:
        try:
            cred = credentials.Certificate(json.loads(raw))
        except Exception as e:
            log.warning("Firebase init from FIREBASE_CREDENTIALS_JSON failed: %s", e)
    # Priority 2: file path (dev path) — resolved relative to backend/ when not absolute
    if cred is None:
        path = config("FIREBASE_CREDENTIALS_FILE", default="")
        if path:
            p = Path(path)
            if not p.is_absolute():
                p = Path(settings.BASE_DIR) / p
            if p.exists():
                try:
                    cred = credentials.Certificate(str(p))
                except Exception as e:
                    log.warning("Firebase init from FIREBASE_CREDENTIALS_FILE=%s failed: %s", p, e)
            else:
                log.warning("FIREBASE_CREDENTIALS_FILE points to nonexistent path: %s (resolved from %s)", p, path)
    if cred is None:
        return False
    try:
        _app = firebase_admin.initialize_app(cred)
        return True
    except Exception as e:
        log.warning("Firebase initialize_app failed: %s", e)
        return False


def send_to_user(user, *, title: str, body: str, link: str = "") -> None:
    """Send a push notification to every device the user has registered. Best-effort — never raises."""
    if not _ensure_initialized(): return
    tokens = list(DeviceToken.objects.filter(user=user).values_list("token", flat=True))
    if not tokens: return
    _send_to_tokens(tokens, title=title, body=body, link=link)


def _send_to_tokens(tokens: Iterable[str], *, title: str, body: str, link: str = "") -> None:
    """Multicast send. Removes stale tokens that FCM rejects (uninstalls, expired registrations)."""
    message = messaging.MulticastMessage(
        tokens=list(tokens),
        notification=messaging.Notification(title=title, body=body),
        # data: arbitrary key/value pairs Flutter reads when the user taps the notification
        data={"link": link},
        android=messaging.AndroidConfig(priority="high",
            notification=messaging.AndroidNotification(sound="default")))
    try:
        resp = messaging.send_each_for_multicast(message)
        # Clean up tokens FCM rejected as invalid so we stop trying to use them
        stale = [t for t, r in zip(tokens, resp.responses) if not r.success and
                 r.exception and "registration-token-not-registered" in str(r.exception).lower()]
        if stale: DeviceToken.objects.filter(token__in=stale).delete()
    except Exception as e:
        log.warning("FCM send failed: %s", e)
