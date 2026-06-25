// ChatsScreen — real conversation list. Tap a row → /chats/:id detail view.
//
// v3.9.8 layout (WhatsApp/Telegram style):
//   • Avatar circle on the left (first letter of name fallback)
//   • Bold name on the main line
//   • Below: "[Sender]: preview…" — single line, ellipsis truncated. Sender is "Siz" if the last
//     message was sent by the current user, otherwise it's the other party's name.
//   • Right side: timestamp (HH:MM today, otherwise dd.MM) + numeric unread badge when > 0.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/chats_repository.dart';
import '../providers/chats_providers.dart';


class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(conversationsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(conversationsProvider),
        child: CustomScrollView(slivers: [
          SliverAppBar.large(title: Text(t.chatsTitle)),
          async.when(
            data: (page) => page.results.isEmpty
                ? SliverFillRemaining(hasScrollBody: false, child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.forum_outlined, size: 56, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(t.noConversationsYet,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                    ])))
                : SliverPadding(padding: const EdgeInsets.symmetric(vertical: 4),
                    sliver: SliverList.separated(
                      itemCount: page.results.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 76),
                      itemBuilder: (_, i) => _ChatRow(c: page.results[i]))),
            loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()))),
            error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24),
                child: Center(child: Text(t.failedPrefix(e.toString()))))),
          ),
        ]),
      ),
    );
  }
}


class _ChatRow extends StatelessWidget {
  final Conversation c;
  const _ChatRow({required this.c});

  /// "13:42" if the message landed today, "26.06" otherwise. We don't pull in `intl` for a single
  /// formatting style — manual is cheaper than the dep cost.
  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      if (sameDay) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final displayName = c.otherUserName.isNotEmpty ? c.otherUserName : c.otherUserEmail;
    final hasMessage = c.lastMessagePreview.isNotEmpty;
    // Sender label — "Siz: …" for our own messages, "Other Name: …" otherwise. Empty conversation
    // gets a "Yangi suhbat" placeholder so the row never renders an empty subtitle.
    final senderLabel = c.lastMessageIsMine
        ? 'Siz'
        : (c.lastMessageSenderName.isNotEmpty ? c.lastMessageSenderName : displayName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/chats/${c.id}'),
      leading: CircleAvatar(radius: 26,
        backgroundColor: cs.primaryContainer,
        child: Text(displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
            style: TextStyle(color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w800, fontSize: 18))),
      title: Row(children: [
        Expanded(child: Text(displayName,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800,
                letterSpacing: -0.2))),
        if (c.lastMessageAt != null) Padding(padding: const EdgeInsets.only(left: 8),
            child: Text(_formatTimestamp(c.lastMessageAt),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600))),
      ]),
      subtitle: Padding(padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Expanded(child: hasMessage
              ? RichText(maxLines: 1, overflow: TextOverflow.ellipsis,
                  text: TextSpan(style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    children: [
                      TextSpan(text: '$senderLabel: ',
                          style: TextStyle(color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700)),
                      TextSpan(text: c.lastMessagePreview),
                    ]))
              : Text("Yangi suhbat",
                  style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant, fontStyle: FontStyle.italic))),
          if (c.unreadCount > 0) Container(
            margin: const EdgeInsets.only(left: 8),
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: cs.primary,
                borderRadius: BorderRadius.circular(999)),
            child: Center(child: Text(c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                style: TextStyle(color: cs.onPrimary, fontSize: 11,
                    fontWeight: FontWeight.w800, height: 1.0)))),
        ])),
    );
  }
}
