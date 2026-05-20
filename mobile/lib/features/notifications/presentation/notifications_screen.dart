// Notifications list — Apple-style large title, grouped rows with unread dot indicator + auto-mark-read on tap.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/notification.dart';
import '../providers/notifications_providers.dart';


class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(notificationsListProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref..invalidate(notificationsListProvider)..invalidate(unreadNotificationsCountProvider);
        },
        child: CustomScrollView(slivers: [
          SliverAppBar.large(
            title: Text(t.notificationsTitle),
            actions: [
              TextButton(onPressed: () async {
                await ref.read(notificationsRepositoryProvider).markAllRead();
                ref..invalidate(notificationsListProvider)..invalidate(unreadNotificationsCountProvider);
              }, child: Text(t.markAllRead)),
            ],
          ),
          async.when(
            data: (page) => page.results.isEmpty
                ? SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text(t.noNotificationsYet,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant))))
                : SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: page.results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _NotificationRow(notification: page.results[i]))),
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


/// One row in the notification list — icon (kind-specific), title, message preview, unread dot, deep-link tap.
class _NotificationRow extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationRow({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final faded = notification.isRead ? 0.6 : 1.0;
    return Material(
      color: notification.isRead ? cs.surfaceContainerLowest : cs.primaryContainer.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (!notification.isRead) await ref.read(notificationsRepositoryProvider).markRead(notification.id);
          ref..invalidate(notificationsListProvider)..invalidate(unreadNotificationsCountProvider);
          if (notification.link.isNotEmpty && context.mounted) context.push(notification.link);
        },
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: cs.secondaryContainer.withValues(alpha: 0.7)),
              child: Icon(_iconFor(notification.kind), size: 20, color: cs.onSecondaryContainer)),
            const SizedBox(width: 12),
            Expanded(child: Opacity(opacity: faded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(notification.title, style: tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (notification.message.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(notification.message, style: tt.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]))),
            // Unread dot — small primary-colored circle when this row hasn't been read
            if (!notification.isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
          ]))));
  }

  static IconData _iconFor(NotificationKind k) => switch (k) {
    NotificationKind.supplierVerified => Icons.verified_outlined,
    NotificationKind.orderPlaced => Icons.shopping_bag_outlined,
    NotificationKind.orderStatusChanged => Icons.local_shipping_outlined,
    NotificationKind.orderCancelled => Icons.cancel_outlined,
    NotificationKind.other => Icons.notifications_outlined,
  };
}
