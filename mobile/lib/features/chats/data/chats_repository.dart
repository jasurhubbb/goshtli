// ChatsRepository — conversation list, message history, send, start-chat.
//
// Polling model: chat screen calls fetchMessages every few seconds while open. Acceptable latency for v2; real-time
// requires WebSockets which we'll wire up later.
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/paginated.dart';
import '../../listings/data/listings_repository.dart' show ApiException;


/// Compact summary used by the conversation list. Matches the backend ConversationSerializer fields.
/// v3.9.8 adds `lastMessageSenderName` + `lastMessageIsMine` so the list row can render the
/// "[Other]\n[Sender]: text…" format used by Telegram / WhatsApp without a second roundtrip.
class Conversation {
  final int id;
  final int otherUserId;
  final String otherUserEmail;
  final String otherUserName;
  final String? lastMessageAt;
  final String lastMessagePreview;
  final String lastMessageSenderName;
  final bool lastMessageIsMine;
  final int unreadCount;

  const Conversation({required this.id, required this.otherUserId, required this.otherUserEmail,
                      required this.otherUserName, required this.lastMessageAt,
                      required this.lastMessagePreview,
                      required this.lastMessageSenderName, required this.lastMessageIsMine,
                      required this.unreadCount});

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as int,
        otherUserId: j['other_user_id'] as int,
        otherUserEmail: (j['other_user_email'] ?? '') as String,
        otherUserName: (j['other_user_name'] ?? '') as String,
        lastMessageAt: j['last_message_at'] as String?,
        lastMessagePreview: (j['last_message_preview'] ?? '') as String,
        lastMessageSenderName: (j['last_message_sender_name'] ?? '') as String,
        lastMessageIsMine: (j['last_message_is_mine'] ?? false) as bool,
        unreadCount: (j['unread_count'] ?? 0) as int);
}


/// One message in a chat. Used by the chat detail screen's bubble list.
class ChatMessage {
  final int id;
  final String senderEmail;
  final String text;
  final bool readByRecipient;
  final String createdAt;

  const ChatMessage({required this.id, required this.senderEmail, required this.text,
                     required this.readByRecipient, required this.createdAt});

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as int,
        senderEmail: (j['sender_email'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        readByRecipient: (j['read_by_recipient'] ?? false) as bool,
        createdAt: (j['created_at'] ?? '') as String);
}


class ChatsRepository {
  final ApiClient _api;
  ChatsRepository(this._api);

  Future<Paginated<Conversation>> listConversations() async {
    final r = await _api.dio.get('/chats/');
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, Conversation.fromJson);
    throw _err(r);
  }

  /// Idempotent — backend returns the existing conversation if one already exists for the pair.
  Future<Conversation> startWith(int otherUserId) async {
    final r = await _api.dio.post('/chats/start/', data: {'other_user_id': otherUserId});
    if (r.statusCode == 200 || r.statusCode == 201) return Conversation.fromJson(r.data as Map<String, dynamic>);
    throw _err(r);
  }

  /// Fetches the conversation's full message history. Backend auto-marks unread inbound messages as read.
  Future<Paginated<ChatMessage>> fetchMessages(int convId) async {
    final r = await _api.dio.get('/chats/$convId/messages/');
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, ChatMessage.fromJson);
    throw _err(r);
  }

  Future<ChatMessage> sendMessage(int convId, String text) async {
    final r = await _api.dio.post('/chats/$convId/messages/', data: {'text': text});
    if (r.statusCode == 201) return ChatMessage.fromJson(r.data as Map<String, dynamic>);
    throw _err(r);
  }

  ApiException _err(Response r) => ApiException(r.data is Map && (r.data as Map)['detail'] is String
      ? (r.data as Map)['detail'] as String : 'HTTP ${r.statusCode}');
}
