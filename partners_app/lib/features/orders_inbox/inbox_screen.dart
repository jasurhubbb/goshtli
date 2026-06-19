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

  Future<void> _act(String path) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).dio.post(path);
      ref.invalidate(inboxProvider(widget.bucket));
    } catch (_) {} finally {
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
              onPressed: _busy ? null : () => _act('/partner/orders/${r['id']}/reject/'),
              child: Text(t.ordersReject))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: _busy ? null : () => _act('/partner/orders/${r['id']}/accept/'),
              child: Text(widget.isQassob ? t.jobsClaim : t.ordersAccept))),
          ]),
        ],
      ]));
  }
}
