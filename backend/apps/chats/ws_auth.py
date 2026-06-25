"""JWT authentication middleware for Django Channels WebSocket connections.

The REST API uses `Authorization: Bearer <access_token>`, but browsers can't set headers on
`new WebSocket(...)` so the mobile clients must pass the JWT either via:
    1. `Sec-WebSocket-Protocol: bearer.<token>` subprotocol (cleanest, no URL leak), OR
    2. `?token=<access_token>` query string fallback (simplest for the Flutter web_socket_channel
       plugin which doesn't expose subprotocol headers cleanly).

We accept both. The middleware decodes the token through SimpleJWT's untyped validator (which
checks signature + expiry + audience) and attaches the User to scope["user"]. Failure → AnonymousUser
so consumers can `close(code=4001)` themselves; we don't 401 mid-handshake because Channels' middleware
contract doesn't expose handshake-rejection semantics.
"""
from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser


@database_sync_to_async
def _user_from_token(token: str):
    """Synchronously validate the JWT and resolve the User. Wrapped in database_sync_to_async so the
    async consumer can await it without blocking the event loop."""
    from rest_framework_simplejwt.tokens import UntypedToken
    from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
    from django.contrib.auth import get_user_model
    try:
        validated = UntypedToken(token)
    except (InvalidToken, TokenError):
        return AnonymousUser()
    user_id = validated.get("user_id")
    if user_id is None:
        return AnonymousUser()
    User = get_user_model()
    try:
        return User.objects.get(pk=user_id, is_active=True)
    except User.DoesNotExist:
        return AnonymousUser()


def _extract_token(scope) -> str | None:
    """Pull the access token out of the WS handshake. Subprotocol takes precedence over query string
    because the former never leaks into proxy logs / browser history. Subprotocol shape: `bearer.<jwt>`.
    """
    # 1) Sec-WebSocket-Protocol subprotocols arrive as scope["subprotocols"] (list of strings).
    for proto in scope.get("subprotocols", []):
        if isinstance(proto, str) and proto.startswith("bearer."):
            return proto[len("bearer."):] or None
    # 2) Fallback — ?token= query string.
    qs = scope.get("query_string", b"")
    if isinstance(qs, bytes):
        qs = qs.decode(errors="ignore")
    parsed = parse_qs(qs)
    raw = parsed.get("token", [])
    return raw[0] if raw else None


class JwtAuthMiddleware(BaseMiddleware):
    """Wraps the inner ASGI app, attaching `scope["user"]` based on the JWT in the handshake."""

    async def __call__(self, scope, receive, send):
        token = _extract_token(scope)
        scope["user"] = await _user_from_token(token) if token else AnonymousUser()
        return await super().__call__(scope, receive, send)


def JwtAuthMiddlewareStack(inner):
    """Convenience constructor mirroring channels' `AuthMiddlewareStack` — keeps asgi.py readable."""
    return JwtAuthMiddleware(inner)
