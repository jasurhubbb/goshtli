"""WebSocket consumer for the 1:1 chat.

URL pattern: `ws/chats/<int:conv_id>/?token=<jwt>` (or with `bearer.<jwt>` subprotocol).

Lifecycle:
  • connect()    → verify token gave us a real user, verify they're a participant of the conversation,
                   join the channel group `chat_<conv_id>`, send recent history (last 50 messages).
  • receive_json → persist {text: "..."} as a Message, broadcast to the channel group, also fire FCM
                   data to the OTHER participant so they get a push if their app is backgrounded.
  • disconnect() → leave the group.

The wire shape we expect from clients:
    inbound:  {"type": "msg", "text": "salom"}
    outbound: {"type": "msg",
               "id": 42, "conversation_id": 7,
               "sender_id": 25, "sender_email": "x@y", "text": "salom",
               "created_at": "2026-06-26T17:02:31+05:00",
               "read_by_recipient": false}
    history:  {"type": "history", "items": [...]}    — pushed on connect

We deliberately don't surface typing/presence here in v1 — they can land via the same group later
(both layers — typing and presence — are commonly added in a follow-up after the basic message
loop proves stable).
"""
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.contrib.auth import get_user_model
from django.utils import timezone

from .models import Conversation, Message


# Code values per RFC 6455. 4001-4999 are app-defined.
WS_CLOSE_UNAUTHENTICATED = 4001
WS_CLOSE_NOT_FOUND = 4404
WS_CLOSE_NOT_PARTICIPANT = 4403


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """One instance per open WebSocket. Joins the `chat_<conv_id>` group so peers see messages in
    real time even when the message originated on a different uvicorn worker."""

    async def connect(self):
        user = self.scope.get("user")
        if user is None or not user.is_authenticated:
            # No JWT or invalid → reject before we even ACK the handshake.
            await self.accept()
            await self.close(code=WS_CLOSE_UNAUTHENTICATED)
            return

        try:
            self.conv_id = int(self.scope["url_route"]["kwargs"]["conv_id"])
        except (KeyError, ValueError):
            await self.accept(); await self.close(code=WS_CLOSE_NOT_FOUND); return

        conv = await self._get_conversation(self.conv_id, user.id)
        if conv is None:
            await self.accept(); await self.close(code=WS_CLOSE_NOT_PARTICIPANT); return

        self.user_id = user.id
        self.group_name = f"chat_{self.conv_id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept(subprotocol=self._negotiated_subprotocol())

        # Push the last 50 messages so the client can render history without an HTTP round-trip.
        history = await self._recent_history(self.conv_id)
        await self.send_json({"type": "history", "items": history})

        # v3.9.8 — eager-mark every inbound message as read on connect (mirrors the HTTP MessageList
        # GET behavior). Then broadcast a "read" event to the channel group so the OTHER side's
        # connected client can flip its bubble checkmarks to "blue ticks" without polling.
        marked_ids = await self._mark_inbound_as_read(self.conv_id, self.user_id)
        if marked_ids:
            await self.channel_layer.group_send(self.group_name, {
                "type": "chat.read",
                "reader_id": self.user_id,
                "message_ids": marked_ids,
            })

    async def disconnect(self, code):
        # group_name only exists when connect() succeeded; guard for the early-close paths above.
        group = getattr(self, "group_name", None)
        if group is not None:
            await self.channel_layer.group_discard(group, self.channel_name)

    async def receive_json(self, content, **kwargs):
        msg_type = content.get("type")
        if msg_type != "msg":
            # Silently ignore unknown types so future client versions can send extra control frames
            # without our older consumers crashing.
            return
        text = (content.get("text") or "").strip()
        if not text:
            return
        # Persist + bump last_message_at on the conversation (single DB hop courtesy of services.py
        # being inline here — we don't reach into services because we already have conv_id from connect).
        row = await self._persist_message(self.conv_id, self.user_id, text)
        if row is None:
            return

        # Broadcast to everyone subscribed to this conversation's group — including ourselves so the
        # sender sees the persisted-id + timestamp echo without trusting the optimistic local copy.
        await self.channel_layer.group_send(self.group_name, {
            "type": "chat.message",
            "row": row,
        })

        # Best-effort outbound push to the other participant via the existing FCM rail. Wrapped so a
        # missing/invalid FCM cert never crashes the message-send path — the persisted Message row
        # is the canonical record.
        await self._notify_offline_recipient(self.conv_id, self.user_id, row)

    async def chat_message(self, event):
        """Group event handler. event['row'] is the serialized message dict from receive_json."""
        await self.send_json({"type": "msg", **event["row"]})

    async def chat_read(self, event):
        """Group event handler — peer just opened the chat / scrolled, marking our messages read.
        We forward the event to OUR own client so the sender's bubbles can flip to read state."""
        # Don't echo our own reads back to ourselves — only the OTHER side needs the visual update.
        if event.get("reader_id") == self.user_id:
            return
        await self.send_json({
            "type": "read",
            "reader_id": event.get("reader_id"),
            "message_ids": event.get("message_ids", []),
        })

    # ---- helpers (sync-DB calls wrapped via database_sync_to_async) --------------------------------

    @database_sync_to_async
    def _get_conversation(self, conv_id: int, user_id: int):
        """Returns the conversation row IFF the caller is one of its two participants."""
        try:
            conv = Conversation.objects.get(pk=conv_id)
        except Conversation.DoesNotExist:
            return None
        if conv.user_a_id == user_id or conv.user_b_id == user_id:
            return conv
        return None

    @database_sync_to_async
    def _recent_history(self, conv_id: int) -> list[dict]:
        """Last 50 messages, oldest-first (matches the chat-bubble render order)."""
        qs = (Message.objects.filter(conversation_id=conv_id)
              .select_related("sender")
              .order_by("-created_at")[:50])
        rows = list(qs)
        rows.reverse()                                                          # oldest-first
        return [self._serialize(m) for m in rows]

    @database_sync_to_async
    def _mark_inbound_as_read(self, conv_id: int, reader_id: int) -> list[int]:
        """Flip read_by_recipient=True on every message in this conversation that wasn't sent by the
        caller. Returns the list of affected message ids so the caller can broadcast a 'read' event
        to the sender for live tick updates."""
        qs = Message.objects.filter(conversation_id=conv_id, read_by_recipient=False).exclude(
            sender_id=reader_id)
        ids = list(qs.values_list("id", flat=True))
        if ids:
            qs.update(read_by_recipient=True)
        return ids

    @database_sync_to_async
    def _persist_message(self, conv_id: int, sender_id: int, text: str) -> dict | None:
        """Creates Message, bumps Conversation.last_message_at, returns serialized row."""
        try:
            conv = Conversation.objects.get(pk=conv_id)
        except Conversation.DoesNotExist:
            return None
        if conv.user_a_id != sender_id and conv.user_b_id != sender_id:
            return None                                                          # silently drop
        User = get_user_model()
        try:
            sender = User.objects.get(pk=sender_id)
        except User.DoesNotExist:
            return None
        m = Message.objects.create(conversation=conv, sender=sender, text=text)
        conv.last_message_at = timezone.now()
        conv.save(update_fields=("last_message_at",))
        return self._serialize(m)

    @staticmethod
    def _serialize(m: Message) -> dict:
        return {
            "id": m.id,
            "conversation_id": m.conversation_id,
            "sender_id": m.sender_id,
            "sender_email": m.sender.email,
            "text": m.text,
            "read_by_recipient": m.read_by_recipient,
            "created_at": m.created_at.isoformat(),
        }

    @database_sync_to_async
    def _notify_offline_recipient(self, conv_id: int, sender_id: int, row: dict):
        """Mirror the new message into a Notification row + best-effort FCM push to the OTHER party.
        We always create the Notification row (cheap, lives in DB for the bell-icon feed). We always
        send the FCM (the client suppresses display when the chat is already open, mimicking
        Telegram/WhatsApp). Errors are swallowed because chat delivery already succeeded via the WS
        group_send — losing the push is degraded, not failed."""
        try:
            conv = Conversation.objects.get(pk=conv_id)
        except Conversation.DoesNotExist:
            return
        recipient = conv.user_b if conv.user_a_id == sender_id else conv.user_a
        try:
            from apps.notifications.models import Notification
            from apps.notifications.fcm import send_to_user
            preview = row["text"][:100]
            title = row.get("sender_email") or "New message"
            Notification.objects.create(
                user=recipient, kind=Notification.Kind.OTHER,
                title=title, message=preview, link=f"/chats/{conv_id}")
            send_to_user(recipient, title=title, body=preview, link=f"/chats/{conv_id}")
        except Exception:
            return

    def _negotiated_subprotocol(self):
        """If the client offered `bearer.<token>`, the WS spec requires us to either echo back that
        subprotocol or none at all. Echo it so the handshake completes cleanly."""
        for proto in self.scope.get("subprotocols", []):
            if isinstance(proto, str) and proto.startswith("bearer."):
                return proto
        return None
