"""ASGI entry point — production uvicorn serves both HTTP and WebSocket through this app.

Routing:
    http       → Django's get_asgi_application() (preserves all existing DRF views)
    websocket  → JwtAuthMiddlewareStack(URLRouter(websocket_urlpatterns))
                  • JwtAuthMiddlewareStack reads the access token from the handshake (subprotocol
                    or ?token= query) and attaches the authenticated User to scope["user"].
                  • URLRouter dispatches by path — currently only ws/chats/<conv_id>/ → ChatConsumer.

Important ordering: Django setup MUST run before importing apps.chats.routing because the routing
module pulls in models. We do `django.setup()` via get_asgi_application() first.
"""
import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")

from django.core.asgi import get_asgi_application

# Pulling get_asgi_application() FIRST runs django.setup() so model imports below work.
django_asgi_app = get_asgi_application()

# These imports must come AFTER django setup — they pull in app models indirectly.
from channels.routing import ProtocolTypeRouter, URLRouter
from apps.chats.routing import websocket_urlpatterns
from apps.chats.ws_auth import JwtAuthMiddlewareStack


application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": JwtAuthMiddlewareStack(URLRouter(websocket_urlpatterns)),
})
