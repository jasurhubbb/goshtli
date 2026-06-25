// Partner-app chats HTTP layer — list conversations, start a chat, fetch + send messages over plain
// HTTP. The WebSocket path (chat_ws.dart) handles the live message stream once a chat is opened;
// these REST calls cover everything outside that loop (list view, deep-link "start chat from
// notification"), and serve as a fallback when the WS is in its reconnect window.
import 'package:dio/dio.dart';
import 'package:shared_core/shared_core.dart' show ApiClient;


class PartnerConversation {
  final int id;
  final int otherUserId;
  final String otherUserName;
  final String otherUserEmail;
  final String? lastMessageAt;
  final String lastMessagePreview;
  final String lastMessageSenderName;
  final bool lastMessageIsMine;
  final int unreadCount;

  const PartnerConversation({
    required this.id, required this.otherUserId,
    required this.otherUserName, required this.otherUserEmail,
    required this.lastMessageAt, required this.lastMessagePreview,
    required this.lastMessageSenderName, required this.lastMessageIsMine,
    required this.unreadCount,
  });

  factory PartnerConversation.fromJson(Map<String, dynamic> j) => PartnerConversation(
        id: (j['id'] as num).toInt(),
        otherUserId: (j['other_user_id'] as num).toInt(),
        otherUserName: (j['other_user_name'] ?? '') as String,
        otherUserEmail: (j['other_user_email'] ?? '') as String,
        lastMessageAt: j['last_message_at'] as String?,
        lastMessagePreview: (j['last_message_preview'] ?? '') as String,
        lastMessageSenderName: (j['last_message_sender_name'] ?? '') as String,
        lastMessageIsMine: (j['last_message_is_mine'] ?? false) as bool,
        unreadCount: (j['unread_count'] ?? 0) as int,
      );
}


class PartnerChatMessage {
  final int id;
  final String senderEmail;
  final String text;
  final bool readByRecipient;
  final String createdAt;

  const PartnerChatMessage({
    required this.id, required this.senderEmail,
    required this.text, required this.readByRecipient, required this.createdAt,
  });

  factory PartnerChatMessage.fromJson(Map<String, dynamic> j) => PartnerChatMessage(
        id: (j['id'] as num).toInt(),
        senderEmail: (j['sender_email'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        readByRecipient: (j['read_by_recipient'] ?? false) as bool,
        createdAt: (j['created_at'] ?? '') as String,
      );
}


class PartnerChatRepository {
  final ApiClient _api;
  PartnerChatRepository(this._api);

  Future<List<PartnerConversation>> list() async {
    final r = await _api.dio.get('/chats/');
    final data = r.data;
    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => PartnerConversation.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is List) {
      return data.map((e) => PartnerConversation.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  /// Idempotent — backend returns the existing conversation row if one already exists for the pair.
  Future<PartnerConversation> startWith(int otherUserId) async {
    final r = await _api.dio.post('/chats/start/', data: {'other_user_id': otherUserId});
    return PartnerConversation.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<PartnerChatMessage>> fetchMessages(int convId) async {
    final r = await _api.dio.get('/chats/$convId/messages/');
    final data = r.data;
    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => PartnerChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is List) {
      return data.map((e) => PartnerChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  Future<PartnerChatMessage> sendMessage(int convId, String text) async {
    final r = await _api.dio.post('/chats/$convId/messages/', data: {'text': text});
    return PartnerChatMessage.fromJson(r.data as Map<String, dynamic>);
  }

  /// Surface DRF's detail string when DioException carries a 4xx response.
  String errorMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['detail'] is String) return d['detail'] as String;
      return e.message ?? e.toString();
    }
    return e.toString();
  }
}
