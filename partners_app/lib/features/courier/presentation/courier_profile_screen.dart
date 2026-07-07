import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../core/auth/partner_auth_notifier.dart';
import '../data/courier_models.dart';
import '../providers/courier_providers.dart';
import '../../../shared/utils/format.dart';


/// Profil tab — vehicle + plate + phone + photo + lifetime stats + logout.
///
/// Photo edit is a bottom-sheet from ImagePicker; on pick we PATCH multipart. Vehicle & plate use
/// bottom-sheet editors so the field-set stays compact and one-thing-at-a-time.
class CourierProfileScreen extends ConsumerWidget {
  const CourierProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(courierMeProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(e.toString(), style: TextStyle(color: cs.error)))),
      data: (p) => p == null ? const SizedBox.shrink()
          : _ProfileBody(profile: p),
    );
  }
}


class _ProfileBody extends ConsumerWidget {
  final CourierProfile profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(padding: EdgeInsets.zero, children: [
      // Header — big avatar, name, vehicle badge, availability chip.
      Container(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [cs.primary.withValues(alpha: 0.14),
                          cs.primary.withValues(alpha: 0.02)])),
        child: Column(children: [
          Stack(children: [
            CircleAvatar(radius: 44, backgroundColor: cs.primary.withValues(alpha: 0.14),
                backgroundImage: profile.photoUrl.isNotEmpty
                    ? NetworkImage(profile.photoUrl) : null,
                child: profile.photoUrl.isEmpty
                    ? Icon(Icons.person, size: 44, color: cs.primary) : null),
            Positioned(bottom: 0, right: 0,
              child: Material(color: cs.primary, shape: const CircleBorder(),
                child: InkWell(customBorder: const CircleBorder(),
                  onTap: () => _pickPhoto(context, ref),
                  child: const Padding(padding: EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt, color: Colors.white, size: 18))))),
          ]),
          const SizedBox(height: 12),
          Text(profile.fullName.isNotEmpty ? profile.fullName : 'Kuryer',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999)),
            child: Text(_vehicleLabel(profile.vehicleKind),
                style: tt.labelMedium?.copyWith(color: cs.primary,
                    fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StatChip(icon: Icons.star_rounded,
                label: profile.ratingCount > 0
                    ? '${profile.ratingAvg.toStringAsFixed(1)} · ${profile.ratingCount}'
                    : 'Reyting yo\'q'),
            const SizedBox(width: 10),
            _StatChip(icon: Icons.local_shipping_rounded,
                label: '${profile.lifetimeDeliveries} ta'),
          ]),
          const SizedBox(height: 8),
          Text("Umumiy daromad: ${formatSoum(profile.lifetimeEarningsUzs)} so'm",
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ])),
      const SizedBox(height: 12),
      _SettingRow(icon: Icons.badge_outlined, label: 'Ism',
          value: profile.fullName,
          onTap: () => _editText(context, ref, field: 'full_name',
              current: profile.fullName, title: 'Ismingizni kiriting')),
      _SettingRow(icon: Icons.directions_car_rounded, label: 'Transport turi',
          value: _vehicleLabel(profile.vehicleKind),
          onTap: () => _pickVehicle(context, ref, current: profile.vehicleKind)),
      _SettingRow(icon: Icons.confirmation_number_outlined, label: 'Raqam',
          value: profile.vehiclePlate.isNotEmpty ? profile.vehiclePlate : "Belgilanmagan",
          onTap: () => _editText(context, ref, field: 'vehicle_plate',
              current: profile.vehiclePlate, title: 'Transport raqami')),
      _SettingRow(icon: Icons.phone_outlined, label: 'Telefon',
          value: profile.phone.isNotEmpty ? profile.phone : "Belgilanmagan"),
      _SettingRow(icon: Icons.email_outlined, label: 'Email', value: profile.email),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedButton.icon(
          onPressed: () async {
            await ref.read(partnerAuthProvider.notifier).logout();
            if (context.mounted) context.go('/role-pick');
          },
          style: OutlinedButton.styleFrom(
              foregroundColor: cs.error, minimumSize: const Size.fromHeight(52),
              side: BorderSide(color: cs.error.withValues(alpha: 0.30)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Chiqish', style: TextStyle(fontWeight: FontWeight.w800)))),
      const SizedBox(height: 24),
    ]);
  }

  static String _vehicleLabel(String k) => switch (k) {
    'BIKE'          => 'Velosiped/motor',
    'CAR'           => 'Yengil avtomobil',
    'VAN'           => 'Furgon',
    'REFRIGERATOR'  => 'Refrijerator',
    'CHORVA_TAXI'   => 'Chorva taksi',
    _               => 'Belgilanmagan',
  };

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery,
        maxWidth: 1280, imageQuality: 80);
    if (file == null) return;
    final multi = await MultipartFile.fromFile(file.path, filename: file.name);
    try {
      await ref.read(courierRepoProvider).updateMe({'photo': multi});
      ref.invalidate(courierMeProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rasm yangilandi")));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e")));
    }
  }

  Future<void> _editText(BuildContext context, WidgetRef ref,
      {required String field, required String current, required String title}) async {
    final ctrl = TextEditingController(text: current);
    final saved = await showModalBottomSheet<String>(context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Saqlash'))),
        ])));
    if (saved == null) return;
    try {
      await ref.read(courierRepoProvider).updateMe({field: saved});
      ref.invalidate(courierMeProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e")));
    }
  }

  Future<void> _pickVehicle(BuildContext context, WidgetRef ref,
      {required String current}) async {
    const opts = [
      ('BIKE',         'Velosiped/motor'),
      ('CAR',          'Yengil avtomobil'),
      ('VAN',          'Furgon'),
      ('REFRIGERATOR', 'Refrijerator'),
      ('CHORVA_TAXI',  'Chorva taksi'),
    ];
    final picked = await showModalBottomSheet<String>(context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
          children: opts.map((o) => ListTile(
              leading: Icon(current == o.$1
                  ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: Theme.of(ctx).colorScheme.primary),
              title: Text(o.$2),
              onTap: () => Navigator.of(ctx).pop(o.$1))).toList())));
    if (picked == null || picked == current) return;
    try {
      await ref.read(courierRepoProvider).updateMe({'vehicle_kind': picked});
      ref.invalidate(courierMeProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e")));
    }
  }
}


class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(fontWeight: FontWeight.w800)),
      ]));
  }
}


class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _SettingRow({required this.icon, required this.label, required this.value, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(onTap: onTap,
      leading: CircleAvatar(radius: 20,
          backgroundColor: cs.primary.withValues(alpha: 0.10),
          child: Icon(icon, size: 20, color: cs.primary)),
      title: Text(label, style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: cs.onSurfaceVariant)),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800)),
      trailing: onTap == null ? null
          : Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant));
  }
}
