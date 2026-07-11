"""End-to-end tests for the Telegram phone-verification flow.

Focus: the RETURNING-user bug (matching a shared contact by phone, not by a fragile deep-link binding), plus
the security invariants that fix must not break — attacker can't DoS the owner, and typed/forwarded contacts
are rejected. The bot's outbound sendMessage is monkeypatched to capture messages instead of hitting Telegram.
"""
import re

import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.telegram_auth import telegram_api
from apps.telegram_auth.models import TelegramVerification

pytestmark = pytest.mark.django_db

WEBHOOK_SECRET = "test-webhook-secret"
PHONE = "+998993102505"


@pytest.fixture(autouse=True)
def telegram_env(settings, monkeypatch):
    settings.TELEGRAM_WEBHOOK_SECRET = WEBHOOK_SECRET
    settings.TELEGRAM_BOT_TOKEN = "test-token"
    settings.TELEGRAM_BOT_USERNAME = "LeBaraBot"
    settings.TELEGRAM_OTP_PEPPER = "test-pepper"
    sent = []
    monkeypatch.setattr(telegram_api, "send_message",
                        lambda chat_id, text, reply_markup=None: sent.append((chat_id, text)))
    return sent


def _start(client, phone=PHONE):
    r = client.post("/api/v1/auth/telegram/start/", {"phone": phone}, format="json")
    assert r.status_code == 200, r.data
    return r.data["session_token"]


def _share_contact(client, phone, tg_user_id, contact_user_id=None):
    """Simulate a Telegram 'contact' Update hitting our webhook. contact_user_id defaults to the sender id
    (the genuine request_contact case); pass a different value to simulate a forwarded/spoofed contact."""
    cid = tg_user_id if contact_user_id is None else contact_user_id
    update = {"message": {"chat": {"id": tg_user_id}, "from": {"id": tg_user_id, "first_name": "Test"},
                          "contact": {"phone_number": phone, "user_id": cid}}}
    r = client.post("/api/v1/telegram/webhook/", update, format="json",
                    HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN=WEBHOOK_SECRET)
    assert r.status_code == 200
    return r


def _code_from(sent):
    for _chat, text in sent:
        m = re.search(r"Kodingiz:\s*(\d{6})", text)
        if m:
            return m.group(1)
    return None


def _verify(client, session_token, code):
    return client.post("/api/v1/auth/telegram/verify/",
                       {"session_token": session_token, "code": code}, format="json")


def test_returning_user_matches_by_phone(telegram_env):
    """The reported bug: a returning user (already has the bot chat) whose deep link didn't re-fire /start,
    so their session row is UNBOUND (telegram_user_id is null). Sharing their contact must still match by
    phone and deliver a code they can verify."""
    client = APIClient()
    # Simulate "signed up yesterday": an existing user + a consumed VERIFIED row.
    User.objects.create_user_from_phone(phone=PHONE, full_name="Yesterday")

    session = _start(client)
    # The session row is unbound (no telegram_user_id) — exactly the returning-user situation.
    assert TelegramVerification.objects.get(session_token=session).telegram_user_id is None

    _share_contact(client, PHONE, tg_user_id=555)
    code = _code_from(telegram_env)
    assert code is not None, "returning user got no code — the bug"

    r = _verify(client, session, code)
    assert r.status_code == 200, r.data
    assert r.data["new_user"] is False           # existing user → logged straight in
    assert "access" in r.data and "refresh" in r.data


def test_new_user_flow(telegram_env):
    client = APIClient()
    session = _start(client)
    _share_contact(client, PHONE, tg_user_id=777)
    code = _code_from(telegram_env)
    r = _verify(client, session, code)
    assert r.status_code == 200, r.data
    assert r.data["new_user"] is True            # unknown phone → app collects name next
    assert r.data["phone"] == PHONE


def test_attacker_cannot_lock_out_owner(telegram_env):
    """An attacker who knows the victim's number spams /start (creating newer rows). The victim shares their
    own contact — the code binds to the newest row — and the victim must STILL be able to verify with the
    session token their app is holding (verify matches the code across the phone's live rows)."""
    client = APIClient()
    victim_session = _start(client)          # victim's app session (older row)
    _start(client)                            # attacker's /start for the same phone → newer row
    _start(client)                            # and again

    _share_contact(client, PHONE, tg_user_id=999)   # victim shares → code binds to the NEWEST row
    code = _code_from(telegram_env)
    assert code is not None

    r = _verify(client, victim_session, code)       # victim verifies with THEIR (older) session token
    assert r.status_code == 200, r.data             # not locked out


def test_spoofed_contact_rejected(telegram_env):
    """A forwarded / address-book contact (contact.user_id != sender id) must be rejected — no code."""
    client = APIClient()
    _start(client)
    _share_contact(client, PHONE, tg_user_id=111, contact_user_id=222)   # someone else's contact
    assert _code_from(telegram_env) is None


def test_wrong_code_burns_attempts_then_dead(telegram_env):
    client = APIClient()
    session = _start(client)
    _share_contact(client, PHONE, tg_user_id=333)
    real_code = _code_from(telegram_env)
    wrong = "000000" if real_code != "000000" else "111111"
    for _ in range(5):
        assert _verify(client, session, wrong).status_code == 400
    # Code is now burned even for the correct value.
    assert _verify(client, session, real_code).status_code == 400
