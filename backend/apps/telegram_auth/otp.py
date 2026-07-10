"""OTP + phone helpers for Telegram-based phone verification.

Security posture (per NIST 800-63B / OWASP / Twilio best-practice research):
  • 6-digit numeric code from a CSPRNG (`secrets`), zero-padded — kept as a STRING so leading zeros survive.
  • Stored as HMAC-SHA256(pepper, e164 + ":" + code) — never plaintext. A 6-digit code has only ~20 bits of
    entropy, so a plain hash is brute-forceable from a DB dump in milliseconds; the server-side PEPPER (held in
    env, never in the DB) is what actually defeats a DB-only attacker. HMAC is also fast (no per-verify Argon2 cost).
  • Constant-time comparison (`hmac.compare_digest`) to avoid a timing side-channel.
The lifetime / attempt / rate limits live on the model + views (5-min TTL, max 5 attempts, 60s resend cooldown,
5 sends/hr per phone, single-use, only-latest-code-valid).
"""
import hashlib
import hmac
import re
import secrets

from django.conf import settings


CODE_LENGTH = 6
CODE_TTL_SECONDS = 5 * 60                     # 5-minute validity window (inside NIST's 10-min out-of-band max)
MAX_VERIFY_ATTEMPTS = 5                       # wrong entries before the code is burned + a fresh one is required
RESEND_COOLDOWN_SECONDS = 60                 # minimum gap between code sends to the same phone (anti-flood)
MAX_SENDS_PER_HOUR = 5                        # per-phone cap on code sends per rolling hour (toll/abuse guard)
SESSION_TTL_SECONDS = 15 * 60                # a start-session waits this long for the user to share their contact


def _pepper() -> bytes:
    """Server-side secret mixed into every code hash. Prefer a dedicated TELEGRAM_OTP_PEPPER; fall back to
    SECRET_KEY so the feature works without extra config, but a dedicated pepper is strongly recommended so
    rotating it doesn't invalidate JWT signing."""
    pepper = getattr(settings, "TELEGRAM_OTP_PEPPER", "") or settings.SECRET_KEY
    return pepper.encode("utf-8")


def generate_code() -> str:
    """CSPRNG 6-digit code as a fixed-width string. `secrets.randbelow` (not `random`) is mandatory —
    predictable RNG would let an attacker anticipate codes. Zero-padded so "012345" isn't mangled to "12345"."""
    return f"{secrets.randbelow(10 ** CODE_LENGTH):0{CODE_LENGTH}d}"


def hash_code(phone_e164: str, code: str) -> str:
    """HMAC-SHA256(pepper, "<e164>:<code>") hex digest. Binding the phone into the message means a hash for
    phone A can never validate a code entered for phone B, even on a digest collision."""
    msg = f"{phone_e164}:{code}".encode("utf-8")
    return hmac.new(_pepper(), msg, hashlib.sha256).hexdigest()


def code_matches(phone_e164: str, code: str, stored_hash: str) -> bool:
    """Constant-time verify. Returns False on any empty input rather than raising."""
    if not stored_hash or not code:
        return False
    return hmac.compare_digest(hash_code(phone_e164, code), stored_hash)


def new_session_token() -> str:
    """URL-safe token used as the Telegram deep-link `?start=` payload. token_urlsafe emits only
    [A-Za-z0-9_-] which is exactly Telegram's allowed payload charset, and 32 chars is well under the 64 cap."""
    return secrets.token_urlsafe(24)[:32]


def normalize_uz_phone(raw: str) -> str | None:
    """Normalize any Uzbek phone spelling to canonical E.164 `+998XXXXXXXXX`, or None if it isn't a valid
    UZ mobile. Telegram's contact.phone_number arrives with OR without a leading '+' depending on the client,
    so we strip to digits and rebuild — never string-compare the raw values on the two sides.

    Handles: bare national (901234567), with country code (998901234567), 00-prefixed (00998...),
    and the rare local-trunk '8' artifact.
    """
    digits = re.sub(r"\D", "", raw or "")
    if digits.startswith("00998"):
        digits = digits[2:]
    if digits.startswith("8") and len(digits) == 10:      # 8 90 123 45 67 → 998 90...
        digits = "998" + digits[1:]
    if len(digits) == 9:                                   # bare national number
        digits = "998" + digits
    if len(digits) == 12 and digits.startswith("998"):
        return "+" + digits
    return None
