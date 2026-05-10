"""Chat views — conversation list (own pairs), get/post messages (with eager-read marking), start-chat shortcut."""
from django.db.models import Q
from django.utils import timezone
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import User
from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer
from .services import get_or_create_for


class ConversationListView(generics.ListAPIView):
    """GET /api/v1/chats/ — all of caller's conversations, ordered by last_message_at desc."""
    serializer_class = ConversationSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Conversation.objects.none()
        u = self.request.user
        return Conversation.objects.filter(Q(user_a=u) | Q(user_b=u)).select_related("user_a", "user_b")


@extend_schema(parameters=[OpenApiParameter("other_user_id", OpenApiTypes.INT)],
               responses={200: ConversationSerializer, 201: ConversationSerializer})
class StartChatView(APIView):
    """POST /api/v1/chats/start/ {other_user_id: N} — get or create the 1:1 conversation. Returns the conversation row."""
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        other_id = request.data.get("other_user_id")
        if not isinstance(other_id, int): raise ValidationError({"other_user_id": "Required integer."})
        try: other = User.objects.get(pk=other_id)
        except User.DoesNotExist: raise NotFound()
        if other.id == request.user.id: raise ValidationError("Can't start a chat with yourself.")
        conv = get_or_create_for(request.user, other)
        return Response(ConversationSerializer(conv, context={"request": request}).data)


class MessageListCreateView(generics.ListCreateAPIView):
    """GET /api/v1/chats/{conv_pk}/messages/ — message history (paginated). POST sends a new message.

    On GET, any unread messages NOT sent by the caller are flipped to read=True (eager-read marking — keeps the chat
    UI free of an explicit /read endpoint).
    """
    serializer_class = MessageSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def _conversation(self):
        try: conv = Conversation.objects.get(pk=self.kwargs["conv_pk"])
        except Conversation.DoesNotExist: raise NotFound()
        if conv.user_a_id != self.request.user.id and conv.user_b_id != self.request.user.id:
            raise PermissionDenied("Not your conversation.")
        return conv

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Message.objects.none()
        conv = self._conversation()
        # Eager-read: mark messages from the OTHER user as read
        conv.messages.exclude(sender=self.request.user).filter(read_by_recipient=False) \
            .update(read_by_recipient=True)
        return conv.messages.all()

    def create(self, request, *args, **kwargs):
        conv = self._conversation()
        text = (request.data.get("text") or "").strip()
        if not text: raise ValidationError({"text": "Cannot be empty."})
        msg = Message.objects.create(conversation=conv, sender=request.user, text=text)
        # Bump last_message_at on the conversation so the list view sorts correctly
        conv.last_message_at = timezone.now(); conv.save(update_fields=("last_message_at",))
        return Response(MessageSerializer(msg).data, status=status.HTTP_201_CREATED)
