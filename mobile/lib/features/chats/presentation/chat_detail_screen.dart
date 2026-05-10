// ChatDetailScreen — bubble list + composer. Polls /messages every 5s while open so new messages from the other
// side show up without a manual refresh. Stops polling on dispose so we don't burn battery in the background.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../providers/chats_providers.dart';


class ChatDetailScreen extends ConsumerStatefulWidget {
  final int conversationId;
  const ChatDetailScreen({super.key, required this.conversationId});
  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}


class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    // Poll every 5s so inbound messages arrive without a manual refresh. v2 — replaced by websocket later.
    _poller = Timer.periodic(const Duration(seconds: 5), (_) =>
        ref.invalidate(conversationMessagesProvider(widget.conversationId)));
  }

  @override
  void dispose() { _poller?.cancel(); _input.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await ref.read(chatsRepositoryProvider).sendMessage(widget.conversationId, text);
      ref..invalidate(conversationMessagesProvider(widget.conversationId))..invalidate(conversationsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    final myEmail = auth is AuthAuthenticated ? auth.user.email : '';
    final async = ref.watch(conversationMessagesProvider(widget.conversationId));
    return Scaffold(
      appBar: AppBar(title: Text(t.chatsTitle)),
      body: SafeArea(child: Column(children: [
        Expanded(child: async.when(
          data: (page) => ListView.builder(
            controller: _scroll, padding: const EdgeInsets.all(12),
            itemCount: page.results.length,
            itemBuilder: (_, i) {
              final m = page.results[i];
              final mine = m.senderEmail == myEmail;
              return _Bubble(text: m.text, mine: mine);
            }),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(t.failedPrefix(e.toString()))),
        )),
        // Composer pinned at the bottom — text field + send button. Padded for the on-screen keyboard via SafeArea above.
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)))),
          child: Row(children: [
            Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4,
              decoration: const InputDecoration(hintText: 'Message…', isDense: true),
              onSubmitted: (_) => _send())),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: _send, icon: const Icon(Icons.send)),
          ])),
      ])),
    );
  }
}


class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  const _Bubble({required this.text, required this.mine});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = mine ? (cs.primary, cs.onPrimary) : (cs.surfaceContainerHighest, cs.onSurface);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16))),
        child: Text(text, style: TextStyle(color: fg))),
    );
  }
}
