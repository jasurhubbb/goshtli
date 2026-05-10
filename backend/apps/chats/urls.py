"""Chat routes — mounted at /api/v1/chats/."""
from django.urls import path
from .views import ConversationListView, MessageListCreateView, StartChatView

urlpatterns = [
    path("", ConversationListView.as_view(), name="chat-list"),                                # GET own conversations
    path("start/", StartChatView.as_view(), name="chat-start"),                                 # POST get-or-create
    path("<int:conv_pk>/messages/", MessageListCreateView.as_view(), name="chat-messages"),     # GET history · POST send
]
