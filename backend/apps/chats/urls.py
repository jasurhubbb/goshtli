"""Chat routes — mounted at /api/v1/chats/."""
from django.urls import path
from .views import ConversationListView, MessageListCreateView, StartChatView, UnreadTotalView

urlpatterns = [
    path("", ConversationListView.as_view(), name="chat-list"),                                # GET own conversations
    path("start/", StartChatView.as_view(), name="chat-start"),                                 # POST get-or-create
    # /unread-total/ MUST come before /<int:conv_pk>/messages/ so the literal route doesn't get
    # swallowed by the pk converter. Drives the AppBar dot-badge on both apps.
    path("unread-total/", UnreadTotalView.as_view(), name="chat-unread-total"),
    path("<int:conv_pk>/messages/", MessageListCreateView.as_view(), name="chat-messages"),     # GET history · POST send
]
