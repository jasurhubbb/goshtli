// ChatWebSocket — v3.9 WS client wrapping web_socket_channel for the buyer app.
//
// Auth: passes the JWT access token via the `bearer.<token>` subprotocol the backend
// JwtAuthMiddleware accepts (see backend/apps/chats/ws_auth.py). No query-string fallback used
// here — both apps can do subprotocols cleanly.
//
// Lifecycle:
//   • connect()    — opens the WS, listens to incoming JSON frames, surfaces them on .events
//   • send(text)   — queues an outbound {type:"msg", text:"…"} frame
//   • dispose()    — closes the WS + cancels the reconnect timer
//
// Reconnect: simple capped-exponential backoff (1s, 2s, 4s, 8s, 16s, capped). Each reconnect
// re-issues the JWT-bearing subprotocol so a token rotation between drops is handled gracefully.
//
// Wire shapes (matching backend/apps/chats/consumers.py):
//   inbound history : {"type":"history", "items":[{...msg row...}, ...]}
//   inbound msg     : {"type":"msg", "id", "conversation_id", "sender_id", "sender_email", "text",
//                      "created_at", "read_by_recipient"}
//   outbound msg    : {"type":"msg", "text":"..."}
import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';


class ChatWsMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderEmail;
  final String text;
  final bool readByRecipient;
  final String createdAt;

  const ChatWsMessage({
    required this.id, required this.conversationId,
    required this.senderId, required this.senderEmail,
    required this.text, required this.readByRecipient, required this.createdAt,
  });

  factory ChatWsMessage.fromJson(Map<String, dynamic> j) => ChatWsMessage(
        id: (j['id'] as num).toInt(),
        conversationId: (j['conversation_id'] as num).toInt(),
        senderId: (j['sender_id'] as num).toInt(),
        senderEmail: (j['sender_email'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        readByRecipient: (j['read_by_recipient'] ?? false) as bool,
        createdAt: (j['created_at'] ?? '') as String,
      );

  ChatWsMessage copyWithRead(bool read) => ChatWsMessage(
        id: id, conversationId: conversationId,
        senderId: senderId, senderEmail: senderEmail,
        text: text, readByRecipient: read, createdAt: createdAt);
}


/// Tagged-union frame surfaced on the .events stream.
sealed class ChatWsEvent {
  const ChatWsEvent();
}

class ChatWsHistory extends ChatWsEvent {
  final List<ChatWsMessage> items;
  const ChatWsHistory(this.items);
}

class ChatWsNewMessage extends ChatWsEvent {
  final ChatWsMessage message;
  const ChatWsNewMessage(this.message);
}

/// v3.9.8 — backend broadcasts a `read` frame to the chat group when the OTHER party marks our
/// outbound messages as read (they opened the chat). Carries the ids so the bubble list can flip
/// just those messages to "read" instead of refetching the whole history.
class ChatWsRead extends ChatWsEvent {
  final int readerId;
  final List<int> messageIds;
  const ChatWsRead({required this.readerId, required this.messageIds});
}

class ChatWsConnected extends ChatWsEvent {
  const ChatWsConnected();
}

class ChatWsDisconnected extends ChatWsEvent {
  final String reason;
  const ChatWsDisconnected(this.reason);
}


class ChatWebSocket {
  /// Base API URL passed in by the caller — same Env.apiBaseUrl the rest of the app uses. We strip
  /// `/api/v1` + swap scheme to ws/wss for the WebSocket URL.
  final String apiBaseUrl;
  final int conversationId;
  final String accessToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  final _eventsController = StreamController<ChatWsEvent>.broadcast();
  Stream<ChatWsEvent> get events => _eventsController.stream;

  ChatWebSocket({
    required this.apiBaseUrl,
    required this.conversationId,
    required this.accessToken,
  });

  /// Derive `wss://host/ws/chats/<id>/` from `https://host/api/v1` (or ws://+http variants for dev).
  /// The trailing slash matters — Django's URL resolver is strict and a 404 closes the WS instantly.
  String get _wsUrl {
    var base = apiBaseUrl;
    // Strip the API prefix so we end up at the host root.
    final apiIdx = base.indexOf('/api/');
    if (apiIdx >= 0) base = base.substring(0, apiIdx);
    base = base.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$base/ws/chats/$conversationId/';
  }

  void connect() {
    if (_disposed) return;
    try {
      // IOWebSocketChannel.connect allows passing protocols which the backend reads as the bearer token.
      _channel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        protocols: ['bearer.$accessToken'],
        pingInterval: const Duration(seconds: 25),
      );
      _eventsController.add(const ChatWsConnected());
      _sub = _channel!.stream.listen(_onFrame,
          onError: _onError, onDone: _onDone, cancelOnError: true);
      _reconnectAttempt = 0;
    } catch (e) {
      _scheduleReconnect(e.toString());
    }
  }

  void send(String text) {
    final t = text.trim();
    if (t.isEmpty || _channel == null) return;
    final frame = jsonEncode({'type': 'msg', 'text': t});
    _channel!.sink.add(frame);
  }

  void _onFrame(dynamic raw) {
    try {
      final data = raw is String ? jsonDecode(raw) : null;
      if (data is! Map) return;
      final type = data['type'];
      if (type == 'history') {
        final items = ((data['items'] as List?) ?? const [])
            .map((e) => ChatWsMessage.fromJson(e as Map<String, dynamic>)).toList();
        _eventsController.add(ChatWsHistory(items));
      } else if (type == 'msg') {
        _eventsController.add(ChatWsNewMessage(
            ChatWsMessage.fromJson(Map<String, dynamic>.from(data))));
      } else if (type == 'read') {
        final ids = ((data['message_ids'] as List?) ?? const [])
            .map((e) => (e as num).toInt()).toList();
        final readerId = (data['reader_id'] as num?)?.toInt() ?? 0;
        _eventsController.add(ChatWsRead(readerId: readerId, messageIds: ids));
      }
    } catch (_) {/* malformed frame — swallow rather than crash the stream */}
  }

  void _onError(Object err) => _scheduleReconnect(err.toString());
  void _onDone() {
    final closeCode = _channel?.closeCode;
    // 4001/4403/4404 are app-defined auth/perm failures — don't reconnect into them, just propagate.
    if (closeCode == 4001 || closeCode == 4403 || closeCode == 4404) {
      _eventsController.add(ChatWsDisconnected('auth/permission: $closeCode'));
      return;
    }
    _scheduleReconnect('peer closed (${closeCode ?? "normal"})');
  }

  void _scheduleReconnect(String reason) {
    if (_disposed) return;
    _eventsController.add(ChatWsDisconnected(reason));
    _sub?.cancel(); _channel = null;
    final delaySeconds = (1 << _reconnectAttempt.clamp(0, 4)).clamp(1, 16);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    await _eventsController.close();
  }
}
