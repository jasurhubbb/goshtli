import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/network/providers.dart';
import 'data/chat_repository.dart';


/// Partner-side chat list. Reached from the shell AppBar chat icon and from notification deep links.
/// Renders WhatsApp/Telegram-style rows: avatar + bold name + "[Sender]: preview…" subtitle + right
/// side timestamp + unread badge.
class PartnerChatsListScreen extends ConsumerStatefulWidget {
  const PartnerChatsListScreen({super.key});
  @override
  ConsumerState<PartnerChatsListScreen> createState() => _PartnerChatsListScreenState();
}


final partnerChatRepoProvider = Provider<PartnerChatRepository>((ref) =>
    PartnerChatRepository(ref.watch(apiClientProvider)));


final partnerConversationsProvider = FutureProvider<List<PartnerConversation>>((ref) async {
  return ref.read(partnerChatRepoProvider).list();
});


/// v3.9.8 — global unread total for the partner-app AppBar chat-icon badge. 20s pulse mirrors the
/// buyer-side cadence so the supplier/qassob sees the new-message indicator without opening the
/// chats list. Only fires when authenticated; anonymous yields 0.
final partnerUnreadChatsTotalProvider = StreamProvider<int>((ref) async* {
  yield 0;
  while (true) {
    final auth = ref.read(partnerAuthProvider);
    if (auth is AuthAuthenticated) {
      try {
        final api = ref.read(apiClientProvider);
        final r = await api.dio.get('/chats/unread-total/');
        if (r.statusCode == 200 && r.data is Map) {
          yield (r.data['unread'] as num?)?.toInt() ?? 0;
        } else {
          yield 0;
        }
      } catch (_) {
        yield 0;
      }
    } else {
      yield 0;
    }
    await Future<void>.delayed(const Duration(seconds: 20));
  }
});


class _PartnerChatsListScreenState extends ConsumerState<PartnerChatsListScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(partnerConversationsProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chatlar')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(partnerConversationsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString(),
              style: TextStyle(color: cs.error))),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(physics: const AlwaysScrollableScrollPhysics(),
                children: [Padding(padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
                  child: Center(child: Column(children: [
                    Icon(Icons.forum_outlined, size: 56, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text("Hozircha chatlar yo'q",
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                  ])))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 76),
              itemBuilder: (_, i) => _ChatRow(c: rows[i]));
          },
        )),
    );
  }
}


class _ChatRow extends StatelessWidget {
  final PartnerConversation c;
  const _ChatRow({required this.c});

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
    final senderLabel = c.lastMessageIsMine
        ? 'Siz'
        : (c.lastMessageSenderName.isNotEmpty ? c.lastMessageSenderName : displayName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/chats/${c.id}'),
      leading: CircleAvatar(radius: 26,
        backgroundColor: cs.primary.withValues(alpha: 0.14),
        child: Text(displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
            style: TextStyle(color: cs.primary,
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
