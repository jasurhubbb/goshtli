// ChatDetailScreen — v3.9 real-time edition.
//
// Replaces the v2 5s-polling architecture with a Django Channels WebSocket. Optimistic local echo
// when sending (your message bubble appears before the server round-trips), then gets reconciled
// when the canonical row arrives back via the WS group broadcast. Auto-reconnect with capped
// backoff is handled by the underlying ChatWebSocket; the UI just shows a thin "Ulanmoqda…" banner
// when disconnected.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../data/chat_ws.dart';


class ChatDetailScreen extends ConsumerStatefulWidget {
  final int conversationId;
  const ChatDetailScreen({super.key, required this.conversationId});
  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}


class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  ChatWebSocket? _ws;
  StreamSubscription<ChatWsEvent>? _eventsSub;
  final List<ChatWsMessage> _messages = [];
  // Pending optimistic-local bubbles — keyed by a synthetic negative id so they don't collide with
  // real server ids. Cleared when the matching canonical row arrives back via the WS broadcast.
  final List<_PendingMessage> _pending = [];
  bool _connected = false;
  // Only render the banner after this timer fires (~3s of continued disconnect). Most disconnects
  // are transient reconnects under 1s; showing "Ulanmoqda…" instantly creates an anxious flicker.
  Timer? _bannerTimer;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final tokens = ref.read(tokenStorageProvider);
    final token = await tokens.readAccess();
    if (!mounted) return;
    if (token == null) {
      setState(() => _showBanner = true);
      return;
    }
    final ws = ChatWebSocket(
      apiBaseUrl: Env.apiBaseUrl,
      conversationId: widget.conversationId,
      accessToken: token);
    _eventsSub = ws.events.listen(_onEvent);
    ws.connect();
    setState(() => _ws = ws);
  }

  void _onEvent(ChatWsEvent ev) {
    if (!mounted) return;
    setState(() {
      switch (ev) {
        case ChatWsConnected():
          _connected = true;
          _bannerTimer?.cancel(); _bannerTimer = null;
          _showBanner = false;
        case ChatWsDisconnected():
          _connected = false;
          _bannerTimer ??= Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showBanner = !_connected);
          });
        case ChatWsHistory(items: final items):
          _messages..clear()..addAll(items);
          _scrollToBottom();
        case ChatWsNewMessage(message: final m):
          _messages.add(m);
          _pending.removeWhere((p) => p.text == m.text && m.senderId == p.senderId);
          _scrollToBottom();
        case ChatWsRead(messageIds: final ids):
          // Flip read_by_recipient on our own out-bound messages so the bubble checkmark goes from
          // single-tick to double-tick without a refetch. Server marks them; we just mirror the
          // state locally.
          for (var i = 0; i < _messages.length; i++) {
            if (ids.contains(_messages[i].id)) {
              _messages[i] = _messages[i].copyWithRead(true);
            }
          }
      }
    });
  }

  void _scrollToBottom() {
    // Defer until after the rebuild settles so the new item's height is registered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final auth = ref.read(authNotifierProvider);
    final myUid = (auth is AuthAuthenticated) ? auth.user.id : 0;
    _input.clear();
    setState(() {
      _pending.add(_PendingMessage(text: text, senderId: myUid));
    });
    _scrollToBottom();
    _ws?.send(text);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _eventsSub?.cancel();
    _ws?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    final myUid = (auth is AuthAuthenticated) ? auth.user.id : 0;
    final cs = Theme.of(context).colorScheme;

    // Compose the rendered bubble list from server-confirmed messages + pending optimistic ones.
    final bubbles = [
      ..._messages.map((m) => _BubbleData(text: m.text, mine: m.senderId == myUid,
          createdAt: m.createdAt, read: m.readByRecipient)),
      ..._pending.map((p) => _BubbleData(text: p.text, mine: true, pending: true)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.chatsTitle),
        // Tiny connection-status dot on the right edge of the appbar — green/amber. Less obtrusive
        // than the banner approach but enough info for users to debug "why isn't my message going".
        actions: [Padding(padding: const EdgeInsets.only(right: 16),
          child: Center(child: Container(width: 9, height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _connected ? const Color(0xFF1B5E20) : const Color(0xFFEF6C00)))))]),
      body: SafeArea(child: Column(children: [
        if (_showBanner)
          Container(width: double.infinity,
            color: const Color(0xFFFFF4E5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: const Text("Ulanmoqda…",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A4F00),
                    fontWeight: FontWeight.w700, fontSize: 12))),
        Expanded(child: bubbles.isEmpty && !_connected
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: bubbles.length,
                itemBuilder: (_, i) => _Bubble(data: bubbles[i]))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.5)))),
          child: Row(children: [
            Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4,
              decoration: InputDecoration(hintText: t.messageHint, isDense: true),
              onSubmitted: (_) => _send())),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: _send, icon: const Icon(Icons.send)),
          ])),
      ])),
    );
  }
}


class _PendingMessage {
  final String text;
  final int senderId;
  const _PendingMessage({required this.text, required this.senderId});
}


class _BubbleData {
  final String text;
  final bool mine;
  final bool pending;
  final String createdAt;
  final bool read;
  const _BubbleData({required this.text, required this.mine,
                      this.pending = false, this.createdAt = '', this.read = false});
}


class _Bubble extends StatelessWidget {
  final _BubbleData data;
  const _Bubble({required this.data});

  /// HH:MM in the user's local timezone. Empty when the message is still optimistic / has no
  /// server-side timestamp yet.
  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = data.mine
        ? (cs.primary, cs.onPrimary) : (cs.surfaceContainerHighest, cs.onSurface);
    final timeText = _formatTime(data.createdAt);
    final tickColor = data.read ? const Color(0xFF6FE0FF) : fg.withValues(alpha: 0.7);
    // Pending optimistic bubbles render at 70% opacity so the user has a visual cue that the
    // message is in-flight, not yet confirmed by the server.
    return Opacity(opacity: data.pending ? 0.7 : 1.0,
      child: Align(
        alignment: data.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(data.mine ? 16 : 4),
              bottomRight: Radius.circular(data.mine ? 4 : 16))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min, children: [
            Text(data.text, style: TextStyle(color: fg, fontSize: 15)),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (timeText.isNotEmpty) Text(timeText,
                  style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 11)),
              if (data.mine) ...[
                const SizedBox(width: 3),
                // Single tick when sent but not yet read, double tick (blue-tinted) when read.
                Icon(data.read ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14, color: tickColor),
              ],
            ]),
          ]))));
  }
}
