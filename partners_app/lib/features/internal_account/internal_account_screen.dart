import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/auth/role_draft_provider.dart';
import '../../l10n/app_localizations.dart';

/// Account/settings surface for an internal catalog operator. It intentionally avoids the legacy
/// public supplier profile and all seller-facing fields.
class InternalAccountScreen extends ConsumerWidget {
  const InternalAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final auth = ref.watch(partnerAuthProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Icon(Icons.admin_panel_settings_rounded,
                  color: cs.primary, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user?.fullName.isNotEmpty ?? false)
                      ? user!.fullName
                      : t.internalAccountTitle,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (user?.phone.isNotEmpty ?? false)
                  Text(user!.phone,
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(t.internalTeamBadge,
                      style: tt.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            )),
          ]),
        ),
        _SettingsRow(
          icon: Icons.notifications_rounded,
          label: t.profileSectionNotifications,
          onTap: () => context.push('/notifications'),
        ),
        _SettingsRow(
          icon: Icons.language_rounded,
          label: t.profileSectionLanguage,
          onTap: () => _showLanguageSheet(context, ref),
        ),
        _SettingsRow(
          icon: Icons.logout_rounded,
          label: t.profileSectionLogout,
          destructive: true,
          onTap: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<Locale>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              title: Text(t.languageUz),
              onTap: () => Navigator.pop(ctx, const Locale('uz'))),
          ListTile(
              title: Text(t.languageRu),
              onTap: () => Navigator.pop(ctx, const Locale('ru'))),
          ListTile(
              title: Text(t.languageEn),
              onTap: () => Navigator.pop(ctx, const Locale('en'))),
        ]),
      ),
    );
    if (picked != null) {
      await ref.read(localeNotifierProvider.notifier).set(picked);
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.profileSectionLogout),
        content: Text(t.logoutConfirmation),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.profileSectionLogout)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(roleDraftProvider.notifier).clear();
    await ref.read(partnerAuthProvider.notifier).logout();
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? cs.error : cs.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
