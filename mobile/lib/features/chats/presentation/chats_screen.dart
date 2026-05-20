// ChatsScreen — real conversation list. Tap a row → /chats/:id detail view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
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
                : SliverPadding(padding: const EdgeInsets.symmetric(vertical: 8),
                    sliver: SliverList.builder(
                      itemCount: page.results.length,
                      itemBuilder: (_, i) {
                        final c = page.results[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Text(c.otherUserName.isEmpty ? '?' : c.otherUserName[0].toUpperCase(),
                              style: TextStyle(color: cs.onPrimaryContainer))),
                          title: Text(c.otherUserName.isEmpty ? c.otherUserEmail : c.otherUserName,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.lastMessagePreview, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: c.unreadCount > 0
                              ? Container(width: 24, height: 24,
                                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                                  child: Center(child: Text('${c.unreadCount}',
                                    style: TextStyle(color: cs.onPrimary, fontSize: 12, fontWeight: FontWeight.w600))))
                              : null,
                          onTap: () => context.push('/chats/${c.id}'),
                        );
                      })),
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
