"""WebSocket routes for the chat app. Mounted by config/asgi.py under JwtAuthMiddlewareStack."""
from django.urls import path

from .consumers import ChatConsumer


websocket_urlpatterns = [
    # Path mirrors the HTTP shape `/api/v1/chats/<int>/messages/` with `ws/` instead of `/api/v1/`
    # so reverse-proxy routing can distinguish protocols cheaply.
    path("ws/chats/<int:conv_id>/", ChatConsumer.as_asgi()),
]
