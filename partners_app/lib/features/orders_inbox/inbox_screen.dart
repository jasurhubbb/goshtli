import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
    case 'DELIVERED_PENDING_CONFIRMATION': return "Yetkazildi — tasdiq kutilmoqda";
    case 'DELIVERED': return 'Yetkazildi';
    case 'CANCELLED': return 'Bekor qilindi';
  }
  return s;
}


/// Next status for the supplier's forward-advance button. Returns null for terminal states + states the
/// supplier no longer drives (once IN_TRANSIT, a platform courier delivers — see the card logic). Mirrors
/// the backend SUPPLIER_TRANSITIONS in apps/orders/services.py. Note IN_TRANSIT advances to
/// DELIVERED_PENDING_CONFIRMATION (buyer then confirms), NOT straight to DELIVERED — and only a
/// self-delivering supplier ever taps it (courier-delivered orders show the courier card, no button).
String? _nextStatusForSupplier(String current) {
  switch (current) {
    case 'CONFIRMED': return 'PROCESSING';
    case 'PROCESSING': return 'IN_TRANSIT';
    case 'IN_TRANSIT': return 'DELIVERED_PENDING_CONFIRMATION';
  }
  return null;
}


/// "2026-07-11T14:30:00Z" → "11.07.2026 · 14:30" in the device's local time. Small inline formatter to
/// avoid pulling intl into this screen for one date.
String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} · ${two(dt.hour)}:${two(dt.minute)}';
}


/// Uzbek label for a courier's vehicle kind (mirrors the courier profile screen).
String _vehicleLabel(String kind) {
  switch (kind) {
    case 'BIKE': return 'Velosiped/motor';
    case 'CAR': return 'Yengil avtomobil';
    case 'VAN': return 'Furgon';
    case 'REFRIGERATOR': return 'Refrijerator';
    case 'CHORVA_TAXI': return 'Chorva taksi';
  }
  return kind;
}


/// Background color hint for the status pill — green for happy-path forward, amber for waiting, red
/// for cancelled.
Color _statusBg(String s) {
  switch (s) {
    case 'PENDING': case 'AWAITING_QASSOB': case 'DELIVERED_PENDING_CONFIRMATION':
      return const Color(0xFFFFF4E5);
    case 'CANCELLED': return const Color(0xFFFEE7E5);
    case 'DELIVERED': return const Color(0xFFE8F5E9);
    default: return const Color(0xFFE3F2FD);
  }
}

Color _statusFg(String s) {
  switch (s) {
    case 'PENDING': case 'AWAITING_QASSOB': case 'DELIVERED_PENDING_CONFIRMATION':
      return const Color(0xFF8A4F00);
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
    final courier = r['courier'] as Map<String, dynamic>?;
    final courierMode = courier?['mode'] as String?;
    final isInTransit = status == 'IN_TRANSIT';
    final isDpc = status == 'DELIVERED_PENDING_CONFIRMATION';
    // The supplier advances CONFIRMED/PROCESSING normally. Once IN_TRANSIT, a platform courier delivers —
    // so we only keep the advance button for a SELF-delivering supplier; otherwise we show the courier card.
    final showAdvance = widget.bucket == 'active' && next != null
        && (!isInTransit || courierMode == 'self');
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
        // Order date — shown for every status so the supplier knows when it came in.
        if (_fmtDate(r['created_at'] as String?).isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(_fmtDate(r['created_at'] as String?),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ],
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
        // Active bucket — forward-advance button when the supplier still drives the state (CONFIRMED /
        // PROCESSING, or IN_TRANSIT when self-delivering). Qassob-owned states have no button here.
        if (showAdvance) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _busy ? null : () => _advance(orderId, next,
                '${t.ordersAdvance}: ${_statusLabel(next)}'),
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white))
                : Text(isInTransit ? 'Yetkazdim' : '${t.ordersAdvance} → ${_statusLabel(next)}'))),
        ]
        // IN_TRANSIT + platform courier → no advance button; a courier is delivering. Show a non-clickable
        // banner + a tappable "Kuryer haqida" that opens the courier's contact sheet (with call).
        else if (widget.bucket == 'active' && isInTransit) ...[
          const SizedBox(height: 10),
          _CourierDeliveringBanner(courier: courier),
        ]
        // Delivered, waiting for the buyer to tap confirm — informational only.
        else if (widget.bucket == 'active' && isDpc) ...[
          const SizedBox(height: 10),
          Container(width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.hourglass_bottom_rounded, size: 18, color: Color(0xFF8A4F00)),
              const SizedBox(width: 8),
              Expanded(child: Text("Yetkazildi — mijoz tasdiqlashini kutmoqda",
                  style: tt.bodySmall?.copyWith(color: const Color(0xFF8A4F00),
                      fontWeight: FontWeight.w700))),
            ])),
        ],
      ]));
  }
}


/// "Kuryer yetkazmoqda" banner shown on an IN_TRANSIT order that a platform courier is delivering. The
/// banner itself isn't a button; the "Kuryer haqida" link opens a contact sheet with a call button.
class _CourierDeliveringBanner extends StatelessWidget {
  final Map<String, dynamic>? courier;
  const _CourierDeliveringBanner({required this.courier});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final mode = courier?['mode'] as String?;
    final pending = mode == 'pending' || courier == null;
    return Container(width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.delivery_dining_rounded, size: 20, color: Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        Expanded(child: Text(pending ? 'Kuryer tayinlanmoqda…' : 'Kuryer yetkazmoqda',
            style: tt.bodyMedium?.copyWith(color: const Color(0xFF0D47A1),
                fontWeight: FontWeight.w800))),
        if (!pending)
          TextButton(onPressed: () => _showCourierSheet(context, courier!),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact),
            child: const Text('Kuryer haqida', style: TextStyle(fontWeight: FontWeight.w800))),
      ]));
  }
}


/// Courier contact sheet — name, vehicle, rating, phone, and a big "call" button that hands off to the
/// phone's dialer (tel:), exactly like production delivery apps.
void _showCourierSheet(BuildContext context, Map<String, dynamic> courier) {
  final name = (courier['name'] as String?) ?? 'Kuryer';
  final phone = (courier['phone'] as String?) ?? '';
  final vehicleKind = (courier['vehicle_kind'] as String?) ?? '';
  final plate = (courier['vehicle_plate'] as String?) ?? '';
  final ratingCount = (courier['rating_count'] as num?)?.toInt() ?? 0;
  final ratingAvg = double.tryParse('${courier['rating_avg'] ?? 0}') ?? 0;
  showModalBottomSheet(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              CircleAvatar(radius: 26, backgroundColor: cs.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.delivery_dining_rounded, color: cs.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text('Kuryer', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ])),
              if (ratingCount > 0)
                Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFEF9A00)),
                  const SizedBox(width: 2),
                  Text('${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                      style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
            ]),
            if (vehicleKind.isNotEmpty) ...[
              const SizedBox(height: 14),
              _CourierRow(icon: Icons.directions_car_rounded,
                  text: plate.isNotEmpty ? '${_vehicleLabel(vehicleKind)} · $plate'
                                          : _vehicleLabel(vehicleKind)),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CourierRow(icon: Icons.phone_rounded, text: phone),
            ],
            const SizedBox(height: 18),
            SizedBox(height: 52, child: FilledButton.icon(
              onPressed: phone.isEmpty ? null : () async {
                Navigator.pop(ctx);
                await launchUrl(Uri(scheme: 'tel', path: phone));
              },
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.call_rounded),
              label: const Text('Kuryerga qo\'ng\'iroq qilish',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
          ])));
    });
}


class _CourierRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CourierRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 18, color: cs.onSurfaceVariant),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(fontWeight: FontWeight.w700))),
    ]);
  }
}
