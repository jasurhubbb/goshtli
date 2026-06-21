import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';
import 'inbox_providers.dart';


/// Inbox tab — role-aware label/icon set by the shell. Three sub-tabs: New / Active / Done.
class InboxScreen extends ConsumerStatefulWidget {
  final bool isQassob;
  const InboxScreen({super.key, this.isQassob = false});
  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}


class _InboxScreenState extends ConsumerState<InboxScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  static const _buckets = ['new', 'active', 'done'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isQ = widget.isQassob;
    return Column(children: [
      TabBar(controller: _tabCtrl, tabs: [
        Tab(text: isQ ? t.jobsTabOffers : t.ordersTabNew),
        Tab(text: isQ ? t.jobsTabToday : t.ordersTabActive),
        Tab(text: isQ ? t.jobsTabHistory : t.ordersTabDone),
      ]),
      Expanded(child: TabBarView(controller: _tabCtrl,
        children: _buckets.map((b) => _BucketList(bucket: b, isQassob: isQ)).toList())),
    ]);
  }
}


class _BucketList extends ConsumerWidget {
  final String bucket;
  final bool isQassob;
  const _BucketList({required this.bucket, required this.isQassob});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(inboxProvider(bucket));
    return RefreshIndicator(onRefresh: () async => ref.invalidate(inboxProvider(bucket)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(physics: const AlwaysScrollableScrollPhysics(),
              children: [Padding(padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
                child: Center(child: Text(isQassob ? t.jobsEmpty : t.ordersEmpty,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center)))]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OrderCard(row: rows[i], bucket: bucket, isQassob: isQassob),
          );
        },
      ));
  }
}


/// Status name in UZ — localized inline rather than via ARB keys to avoid the gen-l10n round-trip for
/// a v3.8 throwaway. Roll into proper l10n in a later pass once the full status set stabilizes.
String _statusLabel(String s) {
  switch (s) {
    case 'PENDING': return 'Kutilmoqda';
    case 'CONFIRMED': return 'Tasdiqlangan';
    case 'PROCESSING': return 'Tayyorlanmoqda';
    case 'AWAITING_QASSOB': return 'Qassob kutilmoqda';
    case 'PROCESSING_BUTCHER': return 'Qassob ishlamoqda';
    case 'IN_TRANSIT': return "Yo'lda";
    case 'DELIVERED': return 'Yetkazildi';
    case 'CANCELLED': return 'Bekor qilindi';
  }
  return s;
}


/// Next status for the supplier's forward-advance button. Returns null for terminal states + states
/// owned by the qassob, in which case we hide the advance button. Mirrors the backend
/// SUPPLIER_TRANSITIONS table in apps/orders/services.py — keep the two in sync if the state machine
/// grows new edges.
String? _nextStatusForSupplier(String current) {
  switch (current) {
    case 'CONFIRMED': return 'PROCESSING';
    case 'PROCESSING': return 'IN_TRANSIT';
    case 'IN_TRANSIT': return 'DELIVERED';
  }
  return null;
}


/// Background color hint for the status pill — green for happy-path forward, amber for waiting, red
/// for cancelled.
Color _statusBg(String s) {
  switch (s) {
    case 'PENDING': case 'AWAITING_QASSOB': return const Color(0xFFFFF4E5);
    case 'CANCELLED': return const Color(0xFFFEE7E5);
    case 'DELIVERED': return const Color(0xFFE8F5E9);
    default: return const Color(0xFFE3F2FD);
  }
}

Color _statusFg(String s) {
  switch (s) {
    case 'PENDING': case 'AWAITING_QASSOB': return const Color(0xFF8A4F00);
    case 'CANCELLED': return const Color(0xFFB71C1C);
    case 'DELIVERED': return const Color(0xFF1B5E20);
    default: return const Color(0xFF0D47A1);
  }
}


class _OrderCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> row;
  final String bucket;
  final bool isQassob;
  const _OrderCard({required this.row, required this.bucket, required this.isQassob});
  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}


class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _busy = false;

  /// Accept / Reject — both go through this helper. v3.8.3 / v3.8.4: surfaces backend errors via
  /// snackbar (was silent before) AND shows a success snackbar so the supplier knows the action
  /// landed even though the card moves to Jarayonda. Invalidates the 'active' bucket too so the
  /// accepted order appears there without a manual pull-to-refresh.
  Future<void> _act(String path, {required String successMsg}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(apiClientProvider).dio.post(path);
      final data = r.data;
      final ok = (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300);
      if (!ok) {
        final detail = data is Map && data['detail'] is String
            ? data['detail'] as String
            : 'HTTP ${r.statusCode}';
        messenger.showSnackBar(SnackBar(content: Text(detail)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(successMsg),
          duration: const Duration(seconds: 2)));
      ref.invalidate(inboxProvider(widget.bucket));
      ref.invalidate(inboxProvider('active'));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Forward-advance an active order to the next status via /partner/orders/<id>/status/. Same error
  /// surfacing pattern as _act() — backend snackbar on failure, success toast + bucket invalidation
  /// on the happy path. After IN_TRANSIT → DELIVERED the row leaves 'active' and lands in 'done'.
  Future<void> _advance(int orderId, String nextStatus, String successMsg) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(apiClientProvider).dio.post(
          '/partner/orders/$orderId/status/',
          data: {'status': nextStatus});
      final data = r.data;
      final ok = (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300);
      if (!ok) {
        final detail = data is Map && data['detail'] is String
            ? data['detail'] as String
            : 'HTTP ${r.statusCode}';
        messenger.showSnackBar(SnackBar(content: Text(detail)));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(successMsg),
          duration: const Duration(seconds: 2)));
      ref.invalidate(inboxProvider('active'));
      ref.invalidate(inboxProvider('done'));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final r = widget.row;
    final status = (r['status'] as String?) ?? '';
    final next = _nextStatusForSupplier(status);
    final orderId = (r['id'] as num).toInt();
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('#${r['id']}  ·  ${r['listing_name']}',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          Text('${r['total_price']} so\'m',
              style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text('${r['quantity_kg']} kg • ${r['buyer_name']}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        Text(r['delivery_address'] as String? ?? '',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        // Status pill — always visible so the supplier sees where each order sits at a glance.
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _statusBg(status),
                borderRadius: BorderRadius.circular(999)),
            child: Text(_statusLabel(status),
                style: tt.labelMedium?.copyWith(color: _statusFg(status),
                    fontWeight: FontWeight.w800, letterSpacing: 0.3)))),
        if (widget.bucket == 'new') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _busy ? null : () => _act('/partner/orders/$orderId/reject/',
                  successMsg: t.ordersReject),
              child: Text(t.ordersReject))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: _busy ? null : () => _act('/partner/orders/$orderId/accept/',
                  successMsg: widget.isQassob ? t.jobsClaim : t.ordersAccept),
              child: Text(widget.isQassob ? t.jobsClaim : t.ordersAccept))),
          ]),
        ],
        // Active bucket — show advance button when there's a forward edge. Qassob-owned states
        // (AWAITING_QASSOB, PROCESSING_BUTCHER) intentionally have no button on the supplier side
        // because the qassob drives those transitions from their own inbox.
        if (widget.bucket == 'active' && next != null) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _busy ? null : () => _advance(orderId, next,
                '${t.ordersAdvance}: ${_statusLabel(next)}'),
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white))
                : Text('${t.ordersAdvance} → ${_statusLabel(next)}'))),
        ],
      ]));
  }
}
