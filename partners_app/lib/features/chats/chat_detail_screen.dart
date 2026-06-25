import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/config/env.dart';
import '../../core/network/providers.dart';
import 'data/chat_ws.dart';


/// Partner-side chat detail. Same lifecycle + rendering as the buyer-app sibling: open a WebSocket,
/// listen for history + new messages, send via WS, render optimistic local bubbles while the
/// canonical row round-trips back. Auto-reconnect with capped backoff is handled by ChatWebSocket.
class PartnerChatDetailScreen extends ConsumerStatefulWidget {
  final int conversationId;
  const PartnerChatDetailScreen({super.key, required this.conversationId});
  @override
  ConsumerState<PartnerChatDetailScreen> createState() => _PartnerChatDetailScreenState();
}


class _PartnerChatDetailScreenState extends ConsumerState<PartnerChatDetailScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  ChatWebSocket? _ws;
  StreamSubscription<ChatWsEvent>? _eventsSub;
  final List<ChatWsMessage> _messages = [];
  final List<_PendingMessage> _pending = [];
  bool _connected = false;
  String? _statusBanner;

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
      setState(() => _statusBanner = 'Tizimga kiring');
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
          _connected = true; _statusBanner = null;
        case ChatWsDisconnected(reason: final r):
          _connected = false; _statusBanner = 'Ulanmoqda… ($r)';
        case ChatWsHistory(items: final items):
          _messages..clear()..addAll(items);
          _scrollToBottom();
        case ChatWsNewMessage(message: final m):
          _messages.add(m);
          _pending.removeWhere((p) => p.text == m.text && m.senderId == p.senderId);
          _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final auth = ref.read(partnerAuthProvider);
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
    _eventsSub?.cancel();
    _ws?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(partnerAuthProvider);
    final myUid = (auth is AuthAuthenticated) ? auth.user.id : 0;
    final cs = Theme.of(context).colorScheme;

    final bubbles = [
      ..._messages.map((m) => _BubbleData(text: m.text, mine: m.senderId == myUid)),
      ..._pending.map((p) => _BubbleData(text: p.text, mine: true, pending: true)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Chat'),
        actions: [Padding(padding: const EdgeInsets.only(right: 16),
          child: Center(child: Container(width: 9, height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _connected ? const Color(0xFF1B5E20) : const Color(0xFFEF6C00)))))]),
      body: SafeArea(child: Column(children: [
        if (_statusBanner != null)
          Container(width: double.infinity, color: const Color(0xFFFFF4E5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(_statusBanner!,
                style: const TextStyle(color: Color(0xFF8A4F00),
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
              decoration: const InputDecoration(hintText: 'Xabar…', isDense: true),
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
  const _BubbleData({required this.text, required this.mine, this.pending = false});
}


class _Bubble extends StatelessWidget {
  final _BubbleData data;
  const _Bubble({required this.data});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = data.mine
        ? (cs.primary, cs.onPrimary) : (cs.surfaceContainerHighest, cs.onSurface);
    return Opacity(opacity: data.pending ? 0.7 : 1.0,
      child: Align(
        alignment: data.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(data.mine ? 16 : 4),
              bottomRight: Radius.circular(data.mine ? 4 : 16))),
          child: Text(data.text, style: TextStyle(color: fg)))));
  }
}
