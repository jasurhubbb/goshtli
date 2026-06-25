import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/providers.dart';
import 'data/chat_repository.dart';


/// Partner-side chat list. Reached from the dashboard AppBar chat icon and/or push-notification deep
/// link. Pulls /chats/ (HTTP), renders one row per active conversation, taps push /chats/<id>.
class PartnerChatsListScreen extends ConsumerStatefulWidget {
  const PartnerChatsListScreen({super.key});
  @override
  ConsumerState<PartnerChatsListScreen> createState() => _PartnerChatsListScreenState();
}


/// Provider keyed off the api client so a logout/login cycle re-instantiates without leftover state.
final partnerChatRepoProvider = Provider<PartnerChatRepository>((ref) =>
    PartnerChatRepository(ref.watch(apiClientProvider)));


final partnerConversationsProvider = FutureProvider<List<PartnerConversation>>((ref) async {
  return ref.read(partnerChatRepoProvider).list();
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
                  child: Center(child: Text("Hozircha chatlar yo'q",
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16))))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) => _ChatRow(c: rows[i]));
          },
        )),
    );
  }
}


class _ChatRow extends StatelessWidget {
  final PartnerConversation c;
  const _ChatRow({required this.c});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListTile(
      onTap: () => context.push('/chats/${c.id}'),
      leading: CircleAvatar(radius: 24,
          backgroundColor: cs.primary.withValues(alpha: 0.14),
          child: Icon(Icons.person_rounded, color: cs.primary)),
      title: Text(c.otherUserName.isNotEmpty ? c.otherUserName : c.otherUserEmail,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      subtitle: Text(c.lastMessagePreview.isEmpty ? '—' : c.lastMessagePreview,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      trailing: c.unreadCount > 0
          ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: cs.primary,
                  borderRadius: BorderRadius.circular(999)),
              child: Text('${c.unreadCount}',
                  style: tt.labelSmall?.copyWith(color: cs.onPrimary,
                      fontWeight: FontWeight.w800)))
          : null,
    );
  }
}
