// Bell icon for the AppBar — shows a small primary-colored dot when there are unread notifications.
//
// Tap routes to /notifications. We pull the count from unreadNotificationsCountProvider so it auto-refreshes whenever
// the user marks something read or new notifications arrive on subsequent fetches.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notifications_providers.dart';


class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final count = ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;
    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Stack(clipBehavior: Clip.none, children: [
        const Icon(Icons.notifications_outlined),
        if (count > 0) Positioned(top: -2, right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(count > 99 ? '99+' : '$count',
              style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)))),
      ]),
    );
  }
}
