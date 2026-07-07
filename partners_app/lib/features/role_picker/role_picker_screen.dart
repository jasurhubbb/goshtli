import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/role_draft_provider.dart';
import '../../l10n/app_localizations.dart';

/// Role picker — three big cards after language pick:
///   • Qassobman         — slaughter + cut live animals (Firebase OTP)
///   • Go'sht sotaman    — sell raw meat or live animals (Firebase OTP)
///   • Kuryer (v3.9.15)  — delivery driver (email + password issued by ops)
///
/// Picking Qassob/Supplier writes to `roleDraftProvider` and pushes /auth/phone. Kuryer pushes to
/// /auth/courier which is a plain email+password form (no OTP because couriers are admin-provisioned).
class RolePickerScreen extends ConsumerWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.go('/'))),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.rolePickerTitle,
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(t.rolePickerSubtitle, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 28),
          _RoleCard(
            icon: Icons.cut_rounded, accent: const Color(0xFFB71C1C),
            title: t.roleQassobTitle, body: t.roleQassobBody,
            onTap: () => _pick(ref, context, UserRole.qassob)),
          const SizedBox(height: 16),
          _RoleCard(
            icon: Icons.store_rounded, accent: const Color(0xFF1B5E20),
            title: t.roleSupplierTitle, body: t.roleSupplierBody,
            onTap: () => _pick(ref, context, UserRole.supplier)),
          const SizedBox(height: 16),
          // v3.9.15 — courier card. Uses a dedicated email+password login instead of Firebase OTP
          // because courier accounts are provisioned by admins (see the provision_courier command
          // + POST /couriers/admin/provision/).
          _RoleCard(
            icon: Icons.delivery_dining_rounded, accent: const Color(0xFF0D47A1),
            title: 'Kuryer',
            body: "Yetkazib beruvchi — admin bergan email + parol bilan kiring",
            onTap: () async {
              HapticFeedback.selectionClick();
              await ref.read(roleDraftProvider.notifier).set(UserRole.courier);
              if (context.mounted) context.push('/auth/courier');
            }),
        ]))));
  }

  void _pick(WidgetRef ref, BuildContext context, UserRole role) async {
    HapticFeedback.selectionClick();
    await ref.read(roleDraftProvider.notifier).set(role);
    if (context.mounted) context.push('/auth/phone');
  }
}


class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final VoidCallback onTap;
  const _RoleCard({required this.icon, required this.accent, required this.title,
                    required this.body, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(22),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22),
        child: Container(padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Row(children: [
            Container(width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12)),
              child: Icon(icon, color: accent, size: 30)),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ])),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ]))));
  }
}
