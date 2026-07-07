import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/utils/format.dart';
import '../../../shared/utils/map_launcher.dart';
import '../data/courier_models.dart';
import '../providers/courier_providers.dart';


/// Delivery detail — the single most important screen in the courier flow. Layout is a top-to-bottom
/// timeline of a delivery:
///
///   1. Hero: order id + current status pill + payout
///   2. Buyer card: name / phone / notes / call button + chat placeholder
///   3. Pickup card: address + Yo'lga tush button (map deep-link) + Olib ketildim advance
///   4. Dropoff card: address + Yo'lga tush + Yetib bordim advance
///   5. Cash card: how much to collect (if COD), input to enter actual cash collected
///   6. Proof card: image_picker → upload
///   7. Yetkazdim button (only if ARRIVED + proof photo attached)
///
/// This screen is intentionally tall — a courier scrolls once, sees all the state, decides.
class CourierDeliveryDetailScreen extends ConsumerStatefulWidget {
  final int deliveryId;
  const CourierDeliveryDetailScreen({super.key, required this.deliveryId});
  @override
  ConsumerState<CourierDeliveryDetailScreen> createState() => _S();
}

class _S extends ConsumerState<CourierDeliveryDetailScreen> {
  final _cashCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() { _cashCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(deliveryDetailProvider(widget.deliveryId));
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.deliveryId}')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(e.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error)))),
        data: (d) => d == null ? const Center(child: Text("Ma'lumot topilmadi"))
            : _Body(detail: d, cashCtrl: _cashCtrl, submitting: _submitting,
                onAdvance: (to, {int? cash}) => _advance(d, to, cashUzs: cash),
                onUploadProof: () => _uploadProof(d)),
      ),
    );
  }

  Future<void> _advance(DeliveryDetail d, DeliveryStatus to, {int? cashUzs}) async {
    setState(() => _submitting = true);
    try {
      await ref.read(courierRepoProvider).advanceStatus(d.id, to,
          cashCollectedUzs: cashUzs);
      // Bust every list bucket + the detail entry so the next screen renders fresh state.
      ref.invalidate(deliveryDetailProvider(d.id));
      ref.invalidate(deliveriesProvider('queue'));
      ref.invalidate(deliveriesProvider('active'));
      ref.invalidate(deliveriesProvider('done'));
      ref.invalidate(courierDashboardProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Holat yangilandi: ${deliveryStatusLabel(to)}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e")));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _uploadProof(DeliveryDetail d) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera,
        maxWidth: 1600, imageQuality: 82);
    if (file == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(courierRepoProvider).uploadProof(d.id, file.path);
      ref.invalidate(deliveryDetailProvider(d.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rasm yuklandi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e")));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}


class _Body extends StatelessWidget {
  final DeliveryDetail detail;
  final TextEditingController cashCtrl;
  final bool submitting;
  final Future<void> Function(DeliveryStatus, {int? cash}) onAdvance;
  final Future<void> Function() onUploadProof;
  const _Body({required this.detail, required this.cashCtrl, required this.submitting,
      required this.onAdvance, required this.onUploadProof});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = detail.status;
    // Terminal states — no more actions, just show the final state cleanly.
    final isDone = s == DeliveryStatus.delivered || s == DeliveryStatus.cancelled;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      _StatusHero(detail: detail),
      const SizedBox(height: 14),
      _BuyerCard(detail: detail),
      const SizedBox(height: 12),
      _AddressCard(icon: Icons.storefront_rounded, tone: const Color(0xFF0D47A1),
          heading: "Olib ketish manzili", address: detail.pickupAddress,
          lat: _toDouble(detail.pickupLat), lng: _toDouble(detail.pickupLng),
          // Show the primary CTA only when it's the next step for this stage.
          primary: s == DeliveryStatus.assigned
              ? _PrimaryButton(label: 'Olib ketdim',
                  onPressed: submitting ? null : () => onAdvance(DeliveryStatus.pickedUp))
              : null),
      const SizedBox(height: 12),
      _AddressCard(icon: Icons.home_rounded, tone: const Color(0xFF1B5E20),
          heading: "Yetkazish manzili", address: detail.dropoffAddress,
          lat: _toDouble(detail.dropoffLat), lng: _toDouble(detail.dropoffLng),
          primary: switch (s) {
            DeliveryStatus.pickedUp => _PrimaryButton(label: "Yo'lga chiqdim",
                onPressed: submitting ? null : () => onAdvance(DeliveryStatus.enRoute)),
            DeliveryStatus.enRoute  => _PrimaryButton(label: 'Yetib bordim',
                onPressed: submitting ? null : () => onAdvance(DeliveryStatus.arrived)),
            _                       => null,
          }),
      const SizedBox(height: 12),
      // Cash card — only relevant if the buyer pays cash on delivery.
      if (detail.paymentStatus.toUpperCase() != 'PAID')
        _CashCard(detail: detail, controller: cashCtrl),
      if (detail.paymentStatus.toUpperCase() != 'PAID') const SizedBox(height: 12),
      _ProofCard(detail: detail,
          onPressed: submitting ? null : onUploadProof),
      if (!isDone) ...[
        const SizedBox(height: 20),
        SizedBox(height: 56, child: FilledButton.icon(
          onPressed: (s == DeliveryStatus.arrived && !submitting)
              ? () async {
                  final cash = int.tryParse(cashCtrl.text.replaceAll(' ', ''));
                  await onAdvance(DeliveryStatus.delivered, cash: cash);
                }
              : null,
          style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFF1B5E20)),
          icon: submitting
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 22),
          label: const Text('Yetkazdim',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                  letterSpacing: 0.3)))),
        const SizedBox(height: 10),
        // Cancel is destructive — keep it small + red, out of the primary CTA lane.
        if (s != DeliveryStatus.delivered)
          Center(child: TextButton.icon(
              onPressed: submitting ? null : () => _confirmCancel(context),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Yetkazishni bekor qilish'))),
      ] else
        Padding(padding: const EdgeInsets.only(top: 20),
          child: Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF1B5E20)),
              const SizedBox(width: 10),
              Expanded(child: Text('Yetkazish yakunlandi',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            ]))),
    ]);
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final go = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Yetkazishni bekor qilasizmi?'),
      content: const Text("Buyurtma dispatchga qaytariladi. Bu qadam qaytarib bo'lmaydi."),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Yo'q")),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Ha, bekor qilaman')),
      ]));
    if (go == true) await onAdvance(DeliveryStatus.cancelled);
  }

  static double _toDouble(String s) => double.tryParse(s) ?? 0.0;
}


class _StatusHero extends StatelessWidget {
  final DeliveryDetail detail;
  const _StatusHero({required this.detail});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (color, label, desc) = _stateVisual(detail.status);
    return Container(padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.02)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.28))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color,
                  borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: tt.labelMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w900))),
          const Spacer(),
          Text('#${detail.orderId}', style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Text(desc, style: tt.titleMedium?.copyWith(color: cs.onSurface,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.inventory_2_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text('${detail.listingName} · ${detail.quantityKg} kg',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium)),
        ]),
        if (detail.payoutUzs > 0) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.payments_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text("Sizga: ${formatSoum(detail.payoutUzs)} so'm",
                style: tt.bodyMedium?.copyWith(color: cs.primary,
                    fontWeight: FontWeight.w900)),
          ]),
        ],
      ]));
  }

  static (Color, String, String) _stateVisual(DeliveryStatus s) => switch (s) {
    DeliveryStatus.assigned  => (const Color(0xFF0D47A1), 'Yangi',
                                  "Yangi topshiriq. Olib ketishga yo'l oling"),
    DeliveryStatus.pickedUp  => (const Color(0xFF0D47A1), 'Olindi',
                                  "Mahsulot olindi. Xaridor tomon yo'lga chiqing"),
    DeliveryStatus.enRoute   => (const Color(0xFFEF6C00), "Yo'lda",
                                  "Xaridor tomon yo'ldasiz"),
    DeliveryStatus.arrived   => (const Color(0xFF6A1B9A), 'Yetib bordi',
                                  "Xaridorga topshiring va rasmga oling"),
    DeliveryStatus.delivered => (const Color(0xFF1B5E20), 'Yetkazildi',
                                  "Bu buyurtma yakunlangan"),
    DeliveryStatus.cancelled => (Colors.grey, 'Bekor', "Ushbu yetkazish bekor qilindi"),
  };
}


class _BuyerCard extends StatelessWidget {
  final DeliveryDetail detail;
  const _BuyerCard({required this.detail});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 22, backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Icon(Icons.person, color: cs.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detail.buyerName, style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w900)),
            if (detail.buyerPhone.isNotEmpty)
              Text(detail.buyerPhone, style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant)),
          ])),
          if (detail.buyerPhone.isNotEmpty)
            IconButton.filledTonal(onPressed: () async {
                await launchUrl(Uri(scheme: 'tel', path: detail.buyerPhone));
              },
              icon: const Icon(Icons.phone_rounded)),
        ]),
        if (detail.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.note_alt_outlined, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(detail.notes, style: tt.bodySmall)),
            ])),
        ],
        if (detail.timeSlot.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(detail.timeSlot, style: tt.bodySmall),
          ]),
        ],
      ]));
  }
}


class _AddressCard extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String heading;
  final String address;
  final double lat;
  final double lng;
  final Widget? primary;
  const _AddressCard({required this.icon, required this.tone, required this.heading,
      required this.address, required this.lat, required this.lng, this.primary});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasCoords = lat != 0 && lng != 0;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: tone.withValues(alpha: 0.14),
                  shape: BoxShape.circle),
              child: Icon(icon, color: tone, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(heading, style: tt.labelLarge?.copyWith(
              color: cs.onSurfaceVariant, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        Text(address.isNotEmpty ? address : "Manzil kiritilmagan",
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
        if (hasCoords) ...[
          const SizedBox(height: 6),
          Text('($lat, $lng)', style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
              onPressed: hasCoords
                  ? () => openMapChooser(context, lat: lat, lng: lng, label: heading)
                  : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Xaritada', style: TextStyle(fontWeight: FontWeight.w800)))),
          if (primary != null) ...[
            const SizedBox(width: 10),
            Expanded(child: primary!),
          ],
        ]),
      ]));
  }
}


class _CashCard extends StatelessWidget {
  final DeliveryDetail detail;
  final TextEditingController controller;
  const _CashCard({required this.detail, required this.controller});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final expected = int.tryParse(detail.totalPrice.split('.').first) ?? 0;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF6C00).withValues(alpha: 0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.payments_rounded, color: Color(0xFFEF6C00)),
          const SizedBox(width: 8),
          Text("Naqd to'lov", style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900, color: const Color(0xFFE65100))),
        ]),
        const SizedBox(height: 6),
        Text("Xaridordan yig'ib olinadi: ${formatSoum(expected)} so'm",
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        TextField(controller: controller, keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: "Aslida yig'ilgan (so'm)",
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder())),
      ]));
  }
}


class _ProofCard extends StatelessWidget {
  final DeliveryDetail detail;
  final VoidCallback? onPressed;
  const _ProofCard({required this.detail, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final has = detail.proofPhotoUrl.isNotEmpty;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.camera_alt_rounded,
              color: has ? const Color(0xFF1B5E20) : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('Yetkazish isboti', style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900)),
          const Spacer(),
          if (has) const Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 20),
        ]),
        const SizedBox(height: 6),
        Text(has
            ? "Rasm yuklandi. Xaridor tekshirsa foydali bo'ladi."
            : "Xaridorga topshirilgan mahsulotni rasmga oling — bahsli holatlarda himoya",
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        if (has) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(10),
              child: Image.network(detail.proofPhotoUrl, height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(height: 40, child: Center(child: Icon(Icons.broken_image))))),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: onPressed,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(has ? "Rasmni almashtirish" : "Rasmga olish")),
      ]));
  }
}


class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)));
}
