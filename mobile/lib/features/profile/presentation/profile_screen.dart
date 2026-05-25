// Profile screen — Uzum-style purple header card, shortcut rows, "Biz bilan bog'lanish" Telegram sheet.
//
// v3.3 layout:
//   • Top purple header: avatar + name + phone, fully tappable → /profile/settings
//   • Rows (grouped, rounded panels):
//       - Mening buyurtmalarim     → /profile/orders
//       - Sevimli e'lonlar          → /profile/saved
//       - Til (Ilova tili)         → showLanguageSheet
//       - Kartalarim                → coming-soon snackbar (no screen yet)
//       - Biz bilan bog'lanish     → bottom sheet with Telegram → @sarimov_s
//
// Logout + delete account moved into ProfileSettingsScreen (reached from the header).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../../shared/widgets/privacy_tagline.dart';
import '../../admin/data/admin_auth_repository.dart';
import '../../admin/providers/admin_auth_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';


/// Telegram username for the Contact-Us deep link (no @). Kept here so a future support handle change is one line.
const String _telegramSupportHandle = 'sarimov_s';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    if (auth is AuthAnonymous || auth is AuthUnauthenticated) return const _AnonymousProfile();
    if (auth is! AuthAuthenticated) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _AuthedProfile(user: auth.user);
  }
}


/// Authenticated layout — purple header card + grouped shortcut rows.
class _AuthedProfile extends ConsumerWidget {
  final User user;
  const _AuthedProfile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final currentLocale = ref.watch(localeNotifierProvider);
    final localeLabel = switch (currentLocale.languageCode) {
      'ru' => 'Русский', 'uz' => "O'zbekcha", _ => currentLocale.languageCode };

    return Scaffold(
      backgroundColor: cs.surface,
      body: ListView(padding: EdgeInsets.zero, children: [
        // ---------- Purple header card ----------
        // Full-bleed brand-coloured panel; tap anywhere on it to open the settings screen. Mimics the Uzum
        // reference where the avatar + name + phone area is a single big touch target.
        _PurpleHeader(user: user, profileTitle: t.profileTitle,
            editLabel: t.profileTapToEdit,
            onTap: () => context.push('/profile/settings')),
        const SizedBox(height: 16),
        // ---------- Grouped shortcuts (rows 1-4) ----------
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _GroupedShortcuts(items: [
          (Icons.receipt_long_outlined, t.myOrders, () => context.go('/profile/orders'), null),
          (Icons.favorite_border, t.savedListingsTitle, () => context.push('/profile/saved'), null),
          // showLanguageSheet returns Future<void> — wrap in a block-body to match the VoidCallback signature
          (Icons.language, t.appLanguage, () { showLanguageSheet(context, ref); }, localeLabel),
          (Icons.credit_card_outlined, t.profileMyCards,
              () => _showCardsComingSoon(context, t.profileCardsEmpty), null),
        ])),
        const SizedBox(height: 16),
        // ---------- Contact us (own panel) ----------
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _GroupedShortcuts(items: [
          (Icons.chat_bubble_outline, t.profileContactUs, () { _showContactSheet(context, t); }, null),
        ])),
        const SizedBox(height: 24),
        // ---------- Admin entry — outlined button at the bottom; opens a password dialog (client-side gate). ----------
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: Icon(Icons.admin_panel_settings_outlined, color: cs.primary),
            label: Text(t.adminEnterCta, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: cs.outlineVariant)),
            onPressed: () => _promptAdminPassword(context, ref, t),
          )),
        const SizedBox(height: 32),
      ]),
    );
  }

  /// Password gate before opening the admin page. The password goes to /auth/admin-unlock/ which returns
  /// admin JWTs into a SEPARATE keystore (AdminTokenStorage) — the main app's user session is never
  /// touched. So a buyer can enter admin and come back to their buyer session unchanged.
  Future<void> _promptAdminPassword(BuildContext context, WidgetRef ref, AppLocalizations t) async {
    // Already unlocked (admin tokens cached from a previous unlock) → skip the dialog entirely.
    if (ref.read(adminAuthNotifierProvider).isUnlocked) {
      context.push('/admin');
      return;
    }
    final controller = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    String? error;
    bool submitting = false;
    final ok = await showDialog<bool>(context: context, barrierDismissible: false, builder: (dctx) {
      return StatefulBuilder(builder: (dctx, setSt) {
        Future<void> trySubmit() async {
          if (submitting) return;
          setSt(() { submitting = true; error = null; });
          try {
            await ref.read(adminAuthNotifierProvider.notifier).unlock(controller.text);
            if (dctx.mounted) Navigator.pop(dctx, true);
          } on AdminAuthException catch (e) {
            setSt(() { submitting = false; error = e.message.contains('Invalid')
                ? t.adminEnterPasswordWrong : e.message; });
          }
        }
        return AlertDialog(
          title: Text(t.adminEnterPasswordTitle),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: controller, obscureText: true, autofocus: true,
              enabled: !submitting,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => trySubmit(),
              decoration: InputDecoration(hintText: t.adminEnterPasswordHint)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: TextStyle(color: cs.error))),
          ]),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(dctx, false),
                child: Text(t.cancel)),
            FilledButton(onPressed: submitting ? null : trySubmit,
              child: submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t.adminEnterCta)),
          ],
        );
      });
    });
    if (ok == true && context.mounted) context.push('/admin');
  }

  // Stop-gap until Kartalarim has its own screen — keeps the row tap responsive without dead-ending the user.
  void _showCardsComingSoon(BuildContext context, String label) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));

  /// Contact-Us bottom sheet — single Telegram tile per spec (image 3). Opens `tg://resolve?domain=<handle>`,
  /// fallback to `https://t.me/<handle>` if Telegram isn't installed (url_launcher handles the OS-level fallback).
  Future<void> _showContactSheet(BuildContext context, AppLocalizations t) async {
    await showModalBottomSheet(context: context, showDragHandle: true, builder: (sctx) {
      final tt = Theme.of(sctx).textTheme;
      return Padding(padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(sctx).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.only(bottom: 18),
            child: Text(t.profileContactUs, style: tt.titleLarge)),
          // Big Telegram tile — square-ish icon over the label, like the screenshot reference
          InkWell(borderRadius: BorderRadius.circular(16), onTap: () async {
            Navigator.pop(sctx);
            await _openTelegram(context, t);
          }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 64, height: 64,
                decoration: const BoxDecoration(color: Color(0xFF29B6F6), shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 30)),  // paper-plane for Telegram
              const SizedBox(height: 10),
              Text('Telegram', style: tt.bodyMedium),
            ]))),
          const SizedBox(height: 16),
          // Bekor qilish — bottom-of-sheet cancel, matches the reference design
          SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(sctx),
            child: Text(t.cancel, style: tt.titleMedium))),
        ]));
    });
  }

  /// Open Telegram chat with the support handle. tg:// first (jumps straight into the app), then https:// fallback.
  Future<void> _openTelegram(BuildContext context, AppLocalizations t) async {
    final deep = Uri.parse('tg://resolve?domain=$_telegramSupportHandle');
    final web = Uri.parse('https://t.me/$_telegramSupportHandle');
    final launched = await launchUrl(deep, mode: LaunchMode.externalApplication).catchError((_) => false)
        || await launchUrl(web, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.profileTelegramOpenFailed)));
    }
  }
}


/// Purple top card — title, avatar, name, phone, edit hint. The whole surface is one tap target → settings.
class _PurpleHeader extends StatelessWidget {
  final User user;
  final String profileTitle;
  final String editLabel;
  final VoidCallback onTap;
  const _PurpleHeader({required this.user, required this.profileTitle,
      required this.editLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final headerColor = cs.primary;                       // brand seed — used here as a Uzum-style purple/red banner
    final onHeader = cs.onPrimary;
    final displayName = user.fullName.isNotEmpty
        ? user.fullName
        : ('${user.lastName ?? ''} ${user.firstName ?? ''}').trim();
    final initials = displayName.split(' ').take(2).map((s) => s.isEmpty ? '' : s[0]).join().toUpperCase();
    return Material(color: headerColor, child: InkWell(onTap: onTap,
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Centered screen title — language picker pinned right so it's reachable without entering settings
          Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const SizedBox(width: 40),
              Expanded(child: Center(child: Text(profileTitle,
                  style: tt.titleLarge?.copyWith(color: onHeader, fontWeight: FontWeight.w600)))),
              // Inline language picker overrides default icon colour to stay legible on the purple background
              IconTheme(data: IconThemeData(color: onHeader), child: const LanguagePicker()),
            ])),
          const SizedBox(height: 8),
          Row(children: [
            // Avatar — flat white circle with initials; matches the Uzum reference where the avatar is
            // distinctly lighter than the surrounding banner
            Stack(clipBehavior: Clip.none, children: [
              Container(width: 56, height: 56,
                decoration: BoxDecoration(color: onHeader.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Center(child: Text(initials.isEmpty ? '?' : initials,
                  style: tt.titleLarge?.copyWith(color: onHeader, fontWeight: FontWeight.w600)))),
              // Small "edit" affordance — pencil chip on the avatar, hints that the whole card is tappable
              Positioned(bottom: -4, right: -2, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: onHeader, borderRadius: BorderRadius.circular(999)),
                child: Text(editLabel,
                    style: tt.labelSmall?.copyWith(color: headerColor, fontWeight: FontWeight.w600)))),
            ]),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
              Text(displayName.isEmpty ? user.phone : displayName,
                  style: tt.titleMedium?.copyWith(color: onHeader, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(user.phone, style: tt.bodyMedium?.copyWith(color: onHeader.withValues(alpha: 0.85))),
            ])),
          ]),
        ]),
      ))));
  }
}


/// Profile screen for anonymous users (v3 pivot, Instamart-style design).
///
/// Layout: top hero is a brand-coloured section that fills the screen down to ~58% — hosts the for-profile-page.png
/// illustration (sized to fit, never cropped). Below the hero, a white panel with rounded top corners holds a primary
/// "Kirish" CTA, the privacy/terms tagline, a single rounded-card row for "Ilova tili" (replacing Offers/Feedback in
/// the reference), and the app version line.
class _AnonymousProfile extends ConsumerWidget {
  const _AnonymousProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentLocale = ref.watch(localeNotifierProvider);
    // Self-name each language in its own script — what the user actually sees in the row "value" slot
    final localeLabel = switch (currentLocale.languageCode) {
      'ru' => 'Русский', 'uz' => "O'zbekcha", _ => currentLocale.languageCode };
    // Hero colour: deep-red brand seed (matches the Instamart reference's full-bleed top section)
    final heroColor = cs.primary;

    return Scaffold(
      // Body extends behind the status bar so the hero color reaches the top edge — matches the Instamart screenshot
      backgroundColor: heroColor,
      body: Column(children: [
        // ---------- Hero (brand-colour, hosts the illustration pinned to the top) ----------
        // SafeArea handles the status-bar inset. The image fills the screen width and auto-sizes to its natural
        // aspect-ratio height — no Expanded/Center, so no blank red bands above or below.
        SafeArea(bottom: false, child: Image.asset('assets/images/for-profile-page.png',
            width: double.infinity, fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter, filterQuality: FilterQuality.medium)),

        // ---------- White bottom panel with rounded top corners ----------
        // Expanded so the panel grabs all remaining vertical space — its content stays top-aligned, the rest is
        // surface-colour fill (matches Instamart's layout where the panel reaches the tab bar).
        Expanded(child: Container(width: double.infinity,
          decoration: BoxDecoration(color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Primary CTA — full-width "Sign in", routes into the v3.2 phone-auth flow (login/signup unified).
              SizedBox(width: double.infinity, height: 52, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: heroColor, foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => context.push('/auth/phone'),
                child: Text(t.signIn, style: tt.titleMedium?.copyWith(
                    color: cs.onPrimary, fontWeight: FontWeight.w600)))),
              const SizedBox(height: 12),
              // Reusable PrivacyTagline — owns the link-span splitting so any auth/onboarding screen can drop it in
              const PrivacyTagline(),
              const SizedBox(height: 20),
              // Single rounded-card row — only "App language" per the spec (Offers/Feedback in the reference removed).
              _SettingsCard(child: _SettingsTile(
                leading: const Text('🇺🇿', style: TextStyle(fontSize: 22)),
                label: t.appLanguage,
                value: localeLabel,
                onTap: () => showLanguageSheet(context, ref))),
              const SizedBox(height: 16),
              Center(child: Text(t.appVersionLabel('1.0.0'),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
            ]))))),
      ]),
    );
  }
}


/// Rounded-card wrapper used for grouped settings rows in the anonymous profile.
class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
      clipBehavior: Clip.antiAlias,
      child: child);
  }
}


/// Reusable settings-row tile — flag/icon, label, right-aligned value text, chevron. Used inside _SettingsCard.
class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _SettingsTile({required this.leading, required this.label, required this.onTap, this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        SizedBox(width: 28, child: Center(child: leading)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: tt.bodyLarge)),
        if (value != null) Text(value!, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ])));
  }
}


/// Grouped iOS-style shortcuts row (rounded surface, hairline dividers, chevrons). The 4th tuple slot is an
/// optional right-aligned value text — used for "Til" (current language label) and any future setting whose
/// current value should hint at a glance.
class _GroupedShortcuts extends StatelessWidget {
  final List<(IconData, String, VoidCallback, String?)> items;
  const _GroupedShortcuts({required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(decoration: BoxDecoration(color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          ListTile(
            leading: Icon(items[i].$1, color: cs.primary),
            title: Text(items[i].$2, style: tt.bodyLarge),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (items[i].$4 != null) Padding(padding: const EdgeInsets.only(right: 4),
                  child: Text(items[i].$4!,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ]),
            onTap: items[i].$3,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          if (i < items.length - 1) Padding(padding: const EdgeInsets.only(left: 56),
              child: Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.5))),
        ],
      ]));
  }
}
