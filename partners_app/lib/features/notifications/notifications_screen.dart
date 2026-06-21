import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// "Bildirishnomalar" screen — partner's in-app notification feed.
/// Pulls from the shared `/notifications/` endpoint (same one buyer app uses). Marks-all-read on open
/// so the bell badge resets; individual rows show unread state by colored dot.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}


class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget bulk read so the bell badge resets after viewing.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(apiClientProvider).dio.post('/notifications/read-all/');
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(_notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop()),
        title: Text(t.profileSectionNotifications)),
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(_notificationsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _empty(context, cs, t),
          data: (rows) {
            if (rows.isEmpty) return _empty(context, cs, t);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: rows.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NotificationCard(row: rows[i]));
          },
        )),
    );
  }

  /// Single empty-state widget reused on both error + empty data — better UX than a red error toast
  /// when the bell just has nothing yet. Inlined per-locale string avoids regenerating l10n files
  /// just for one extra key; tracked for the next l10n pass.
  Widget _empty(BuildContext context, ColorScheme cs, AppLocalizations t) {
    final lang = Localizations.localeOf(context).languageCode;
    final msg = lang == 'ru' ? 'Уведомлений нет'
              : lang == 'en' ? 'No notifications'
              : 'Bildirishnoma yo\'q';
    return ListView(physics: const AlwaysScrollableScrollPhysics(),
      children: [Padding(padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
        child: Column(children: [
          Icon(Icons.notifications_off_rounded, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(msg,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]))]);
  }
}


/// Defensive parse — DRF list view returns either a paginated `{results:[...]}` envelope or a bare list
/// depending on settings. Collapse both into a List<Map>.
final _notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final r = await ref.read(apiClientProvider).dio.get('/notifications/');
    final data = r.data;
    if (data is Map) {
      final raw = data['results'];
      if (raw is List) return raw.cast<Map<String, dynamic>>();
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  } catch (_) {
    return const [];
  }
});


class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _NotificationCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isRead = row['is_read'] == true;
    final title = (row['title'] as String?) ?? '';
    final msg = (row['message'] as String?) ?? '';
    final when = (row['created_at'] as String?) ?? '';
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isRead ? cs.outlineVariant : const Color(0xFFFFD580))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isRead) Padding(padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: Color(0xFFEF9A00), shape: BoxShape.circle))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title.isNotEmpty)
            Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (msg.isNotEmpty) ...[const SizedBox(height: 2),
            Text(msg, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))],
          if (when.isNotEmpty) ...[const SizedBox(height: 6),
            Text(_short(when), style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant))],
        ])),
      ]));
  }

  /// Trim ISO timestamp to YYYY-MM-DD HH:MM for compact display; defensive against malformed strings.
  String _short(String iso) {
    if (iso.length < 16) return iso;
    return '${iso.substring(0, 10)} ${iso.substring(11, 16)}';
  }
}
