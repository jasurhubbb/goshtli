import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/role_draft_provider.dart';
import '../../l10n/app_localizations.dart';

/// Role picker — the SECOND first-run screen, between language pick and phone OTP. Two big cards:
///   * Qassobman  — slaughter + cut live animals
///   * Go'sht sotaman — sell raw meat or live animals (may also deliver)
///
/// Picking writes to `roleDraftProvider` (SharedPreferences). The onboarding wizard reads it AFTER
/// the user completes Firebase OTP + lands on /auth/details as a new user, to know which question
/// set to render.
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
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
