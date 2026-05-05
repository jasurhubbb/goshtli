// Riverpod providers for the notifications feature.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/notification.dart';
import '../../../shared/models/paginated.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../data/notifications_repository.dart';


final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) =>
    NotificationsRepository(ref.watch(apiClientProvider)));


final notificationsListProvider = FutureProvider.autoDispose<Paginated<AppNotification>>((ref) async =>
    ref.watch(notificationsRepositoryProvider).list());


/// Unread badge count — only fetched when there's an authenticated user; otherwise stays at 0 to avoid 401 spam.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  if (ref.watch(authNotifierProvider) is! AuthAuthenticated) return 0;
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});
