import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import 'edit_profile_sheet.dart';


/// Partner Profil tab.
///
/// v3.8.1 trimmed sections per product decision:
///   * removed "Biznes ma'lumotlari" — covered by Profilni tahrirlash
///   * removed "Hujjatlar" — superadmins verify partners directly; no KYC upload UX
///   * removed "Doimiy mijozlar" — moved out of v1 scope
/// Kept: Profilni tahrirlash, Sharhlar, Bildirishnomalar, Til, Telegram support, Chiqish.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}


class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Loads the role-specific profile (qassobs/me or suppliers/me) so we know the current
  /// phone_visible value to pass to the edit sheet.
  Future<void> _loadProfile() async {
    final auth = ref.read(partnerAuthProvider);
    if (auth is! AuthAuthenticated) return;
    try {
      final api = ref.read(apiClientProvider);
      final path = auth.user.isQassob ? '/qassobs/me/' : '/suppliers/me/';
      final r = await api.dio.get(path);
      if (mounted && r.data is Map) {
        setState(() => _profile = Map<String, dynamic>.from(r.data as Map));
      }
    } catch (_) {
      // Profile not yet created or transient error — UI just falls back to defaults.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final auth = ref.watch(partnerAuthProvider);
    final dashboard = ref.watch(dashboardProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final verified = dashboard.value?['is_verified'] == true;

    return ListView(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Row(children: [
          CircleAvatar(radius: 32, backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Icon(Icons.person_rounded, color: cs.primary, size: 32)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.fullName ?? '',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(user?.phone ?? '',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: verified ? const Color(0xFFD3EDD3) : const Color(0xFFFFE0B2),
                borderRadius: BorderRadius.circular(999)),
              child: Text(verified ? t.profileVerifiedBadge : t.profilePendingBadge,
                  style: tt.labelSmall?.copyWith(
                      color: verified ? const Color(0xFF1F5E1F) : const Color(0xFF8A4F00),
                      fontWeight: FontWeight.w800, letterSpacing: 0.4))),
          ])),
        ])),

      _Section(label: t.profileSectionEdit,
        icon: Icons.edit_rounded,
        onTap: () => _openEdit(context)),
      _Section(label: t.profileSectionReviews,
        icon: Icons.star_rounded, onTap: () {}),
      _Section(label: t.profileSectionNotifications,
        icon: Icons.notifications_rounded, onTap: () {}),
      _Section(label: t.profileSectionLanguage,
        icon: Icons.language_rounded, onTap: () => _showLanguageSheet(context, ref)),
      _Section(label: t.profileSectionSupport,
        icon: Icons.telegram, onTap: () => _openTelegram(t.supportTelegramHandle)),
      _Section(label: t.profileSectionLogout,
        icon: Icons.logout_rounded, destructive: true,
        onTap: () => ref.read(partnerAuthProvider.notifier).logout()),
      const SizedBox(height: 24),
    ]);
  }

  Future<void> _openEdit(BuildContext context) async {
    final user = (ref.read(partnerAuthProvider) is AuthAuthenticated)
        ? (ref.read(partnerAuthProvider) as AuthAuthenticated).user
        : null;
    final saved = await showEditProfileSheet(context,
        currentName: user?.fullName ?? '',
        currentPhoneVisible: (_profile?['phone_visible'] as bool?) ?? true);
    if (saved) {
      // Refresh the role-specific profile so the toggle shows the new state next time.
      _loadProfile();
      // Re-fetch dashboard so the greeting + verification state are fresh too.
      ref.read(dashboardProvider.notifier).refresh();
    }
  }

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<Locale>(
      context: context,
      builder: (ctx) => SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(t.languageUz), onTap: () => Navigator.pop(ctx, const Locale('uz'))),
        ListTile(title: Text(t.languageRu), onTap: () => Navigator.pop(ctx, const Locale('ru'))),
        ListTile(title: Text(t.languageEn), onTap: () => Navigator.pop(ctx, const Locale('en'))),
      ])),
    );
    if (picked != null) await ref.read(localeNotifierProvider.notifier).set(picked);
  }

  Future<void> _openTelegram(String handle) async {
    final handleClean = handle.replaceFirst('@', '');
    final uri = Uri.parse('https://t.me/$handleClean');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}


class _Section extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const _Section({required this.label, required this.icon, required this.onTap,
                   this.destructive = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = destructive ? cs.error : cs.onSurface;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: tt.titleSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
