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

  /// Accept / Reject — both go through this helper. v3.8.3: the old `try{}catch(_){}` silently ate
  /// every backend error (permission denied, invalid transition, stale stock). Supplier saw zero
  /// feedback when Tasdiqlash failed. Now we read the DRF detail off the response and surface it via
  /// snackbar, and we show a success snackbar on the happy path so the supplier knows the action
  /// landed even though the card is about to disappear (bucket re-queries).
  Future<void> _act(String path, {required String successMsg}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(apiClientProvider).dio.post(path);
      // ApiClient's validateStatus accepts <500 so a 4xx comes back as a successful Response with a
      // detail-shaped body — check it explicitly instead of trusting the absence of exceptions.
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
      // The accepted order leaves "Yangi" and lands in "Jarayonda". Invalidate that bucket too so it
      // shows the new row without forcing the supplier to pull-to-refresh.
      ref.invalidate(inboxProvider('active'));
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
        if (widget.bucket == 'new') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _busy ? null : () => _act('/partner/orders/${r['id']}/reject/',
                  successMsg: t.ordersReject),
              child: Text(t.ordersReject))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: _busy ? null : () => _act('/partner/orders/${r['id']}/accept/',
                  successMsg: widget.isQassob ? t.jobsClaim : t.ordersAccept),
              child: Text(widget.isQassob ? t.jobsClaim : t.ordersAccept))),
          ]),
        ],
      ]));
  }
}
