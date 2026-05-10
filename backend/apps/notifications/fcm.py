"""Thin Firebase Cloud Messaging wrapper — lazy-initialized, never raises into business logic.

The credentials JSON is provided via the FIREBASE_CREDENTIALS_JSON env var (the full JSON contents pasted in). If
unset, push is silently disabled — useful for local dev + tests. Failures during send are logged but don't propagate;
notification flow continues even if FCM is unreachable.
"""
import json
import logging
import os
from typing import Iterable

import firebase_admin
from firebase_admin import credentials, messaging

from .models import DeviceToken

log = logging.getLogger(__name__)


_app: firebase_admin.App | None = None


def _ensure_initialized() -> bool:
    """Idempotent init from FIREBASE_CREDENTIALS_JSON env var. Returns False if FCM is not configured (no creds)."""
    global _app
    if _app is not None: return True
    raw = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    if not raw: return False
    try:
        cred = credentials.Certificate(json.loads(raw))
        _app = firebase_admin.initialize_app(cred)
        return True
    except Exception as e:
        log.warning("FCM init failed: %s", e)
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
