import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart' show authNotifierProvider, apiClientProvider;
import '../../auth/providers/auth_state.dart';
import '../../chats/providers/chats_providers.dart';
import '../data/qassob_models.dart';
import '../providers/services_providers.dart';


/// Full-page qassob detail. Lawyer-app-style hero + content sections + fixed-bottom Chat button.
/// Reachable from a Servislar card via `/servislar/{id}`.
///
/// Section order (top → bottom):
///   1. Hero photo + status badge + back button (SliverAppBar with collapsing image)
///   2. Title block — name, rating, region, distance, years-of-experience
///   3. Gallery strip — horizontal scroll of QassobPhoto thumbs
///   4. Specialties — chip row
///   5. Bio — "Men haqimda" paragraph
///   6. Working hours — per-weekday table
///   7. Price list — service / price / unit rows
///   8. Certifications — list with year column
///   9. Languages spoken — chip row
///   10. Contact — phone + telegram quick-launch (when phone_visible/telegram set)
///
/// Fixed at the bottom: a horizontal "Chat" button that POSTs /chats/start/ with the qassob's
/// user_id and pushes `/chats/{conv_id}`. The HTTP chat infrastructure already exists — Phase 6
/// swaps it for WebSockets without changing this entry point.
class QassobDetailScreen extends ConsumerWidget {
  final int qassobId;
  const QassobDetailScreen({super.key, required this.qassobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(qassobByIdProvider(qassobId));
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(message: e.toString()),
        data: (q) => _Body(q: q)),
      bottomNavigationBar: async.maybeWhen(
        data: (q) => _ContactBar(q: q),
        orElse: () => null),
    );
  }
}


/// v3.9.14 — two-option contact bar. LEFT (secondary) = "Raqam qoldirish" opens a small dialog for
/// the buyer to leave their phone + optional note — creates a callback request the qassob sees in
/// Bildirishnomalar with a tap-to-call action. RIGHT (primary) = "Chat" starts a WebSocket chat.
class _ContactBar extends ConsumerWidget {
  final Qassob q;
  const _ContactBar({required this.q});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(top: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(child: SizedBox(height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _openCallbackDialog(context, ref, q),
              icon: const Icon(Icons.phone_outlined),
              label: const Text('Raqam qoldirish',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: SizedBox(height: 54, child: _ChatButtonInner(q: q))),
        ])));
  }
}


Future<void> _openCallbackDialog(BuildContext context, WidgetRef ref, Qassob q) async {
  final phoneCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final sent = await showModalBottomSheet<bool>(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return Padding(padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(top: 6, bottom: 14),
                decoration: BoxDecoration(color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)))),
            Text("Qassob sizga qo'ng'iroq qilsin",
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text("Telefon raqamingizni qoldiring — qassob ko'radi va tez orada aloqaga chiqadi.",
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(border: OutlineInputBorder(),
                  hintText: '+998 90 123 45 67',
                  labelText: 'Telefon raqami *')),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, maxLines: 3, maxLength: 200,
              decoration: const InputDecoration(border: OutlineInputBorder(),
                  labelText: 'Qisqa izoh (ixtiyoriy)',
                  hintText: 'Masalan: 1 ta mol so\'ymoqchiman')),
            const SizedBox(height: 6),
            FilledButton(onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              try {
                await ref.read(apiClientProvider).dio.post(
                    '/qassobs/${q.id}/callback/',
                    data: {'phone': phone, 'note': noteCtrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (_) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text("Yuborilmadi. Qayta urinib ko'ring.")));
              }
            },
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text("Yuborish",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]))));
    });
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Qassob sizga qo'ng'iroq qiladi")));
  }
}


class _ChatButtonInner extends ConsumerStatefulWidget {
  final Qassob q;
  const _ChatButtonInner({required this.q});
  @override
  ConsumerState<_ChatButtonInner> createState() => _ChatButtonInnerState();
}


class _ChatButtonInnerState extends ConsumerState<_ChatButtonInner> {
  bool _busy = false;

  Future<void> _open() async {
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      context.push('/auth/phone');
      return;
    }
    if (widget.q.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Qassob bilan aloqa hozircha mavjud emas (server eski versiya).")));
      return;
    }
    setState(() => _busy = true);
    try {
      final conv = await ref.read(chatsRepositoryProvider).startWith(widget.q.userId!);
      if (!mounted) return;
      context.push('/chats/${conv.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
        onPressed: _busy ? null : _open,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                strokeWidth: 2.2, color: Colors.white))
            : const Icon(Icons.chat_bubble_rounded),
        label: const Text('Chat',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                letterSpacing: 0.3)),
        style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
  }
}


/// Caches the qassob detail per id. autoDispose so navigating away frees the memory.
final qassobByIdProvider = FutureProvider.autoDispose.family<Qassob, int>((ref, id) async {
  return ref.watch(qassobRepositoryProvider).getById(id);
});


class _Body extends StatelessWidget {
  final Qassob q;
  const _Body({required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
      // Collapsing hero — large image at top, explicit circular-frosted back button so it stays
      // visible against bright photos. Plain SliverAppBar.leading rendered as a thin black arrow
      // disappeared on light shopfront shots; the white circle reads at every photo brightness.
      SliverAppBar(
        expandedHeight: 280,
        pinned: true,
        backgroundColor: Colors.white,
        foregroundColor: cs.onSurface,
        automaticallyImplyLeading: false,
        leading: Padding(padding: const EdgeInsets.all(8),
          child: Material(color: Colors.black.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: const SizedBox(width: 40, height: 40,
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18))))),
        flexibleSpace: FlexibleSpaceBar(background: _HeroPhoto(q: q)),
      ),
      SliverToBoxAdapter(child: _TitleBlock(q: q)),
      if (q.gallery.isNotEmpty) SliverToBoxAdapter(child: _GalleryStrip(q: q)),
      if (q.specialties.isNotEmpty) SliverToBoxAdapter(child: _ChipSection(
          title: 'Mutaxassisliklar', items: q.specialties, accent: cs.primary)),
      if (q.bio.isNotEmpty) SliverToBoxAdapter(child: _BioBlock(q: q)),
      if (_hasAnyWorkingHours(q)) SliverToBoxAdapter(child: _HoursBlock(q: q)),
      if (q.priceList.isNotEmpty) SliverToBoxAdapter(child: _PriceListBlock(q: q)),
      if (q.certifications.isNotEmpty) SliverToBoxAdapter(child: _CertificationsBlock(q: q)),
      if (q.languages.isNotEmpty) SliverToBoxAdapter(child: _LanguageBlock(q: q)),
      SliverToBoxAdapter(child: _ContactBlock(q: q)),
      // Generous bottom padding so the last section isn't hidden under the fixed Chat button.
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ]);
  }

  bool _hasAnyWorkingHours(Qassob q) => q.workingHours.values.any((v) => v != null);
}


class _HeroPhoto extends StatelessWidget {
  final Qassob q;
  const _HeroPhoto({required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(fit: StackFit.expand, children: [
      q.photoUrl.isNotEmpty
          ? Image.network(q.photoUrl, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: cs.surfaceContainerLowest,
                  child: Icon(Icons.store_rounded, color: cs.onSurfaceVariant, size: 64)))
          : Container(color: cs.surfaceContainerLowest,
              child: Icon(Icons.store_rounded, color: cs.onSurfaceVariant, size: 64)),
      // Gradient at the bottom of the hero so the title block underneath reads cleanly even when
      // the photo is bright.
      Positioned(bottom: 0, left: 0, right: 0, height: 80,
        child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)])))),
      Positioned(left: 16, bottom: 14,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: q.isOpenNow ? const Color(0xCC1B5E20) : const Color(0xCCB71C1C),
              borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7,
                decoration: const BoxDecoration(color: Colors.white,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(q.isOpenNow ? 'Hozir ochiq' : 'Hozir yopiq',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          ]))),
    ]);
  }
}


class _TitleBlock extends StatelessWidget {
  final Qassob q;
  const _TitleBlock({required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(q.fullName, style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.location_on_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(child: Text(
              '${q.region}${q.distanceKm != null ? ' · ${q.distanceKm!.toStringAsFixed(1)} km' : ''}',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Pill(icon: Icons.star_rounded,
              color: const Color(0xFFEF9A00),
              label: q.ratingCount > 0
                  ? '${q.ratingAvg.toStringAsFixed(1)} (${q.ratingCount})'
                  : 'Yangi'),
          const SizedBox(width: 8),
          if (q.yearsExperience > 0) _Pill(icon: Icons.workspace_premium_outlined,
              color: cs.primary,
              label: AppLocalizations.of(context).servicesYearsExp(q.yearsExperience)),
          if (q.isSlaughterhouse) ...[
            const SizedBox(width: 8),
            _Pill(icon: Icons.factory_outlined,
                color: const Color(0xFF1B5E20), label: 'Qushxona'),
          ],
        ]),
      ]));
  }
}


/// Square photo strip below the title. Each thumb is tappable but for v1 we just show — full-screen
/// photo viewer can come later.
class _GalleryStrip extends StatelessWidget {
  final Qassob q;
  const _GalleryStrip({required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: SizedBox(height: 96,
        child: ListView.separated(scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: q.gallery.length,
          separatorBuilder: (ctx, i) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final p = q.gallery[i];
            return ClipRRect(borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 96, height: 96,
                child: p.imageUrl.isEmpty
                    ? Container(color: cs.surfaceContainerLowest)
                    : Image.network(p.imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: cs.surfaceContainerLowest))));
          })));
  }
}


/// Reusable section header + content padding wrapper so every block has consistent spacing.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900,
            letterSpacing: -0.2)),
        const SizedBox(height: 10),
        child,
      ]));
  }
}


class _ChipSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color accent;
  const _ChipSection({required this.title, required this.items, required this.accent});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _Section(title: title,
      child: Wrap(spacing: 8, runSpacing: 8, children: items.map((s) {
        return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999)),
          child: Text(s, style: tt.bodyMedium?.copyWith(
              color: accent, fontWeight: FontWeight.w800)));
      }).toList()));
  }
}


class _BioBlock extends StatelessWidget {
  final Qassob q;
  const _BioBlock({required this.q});
  @override
  Widget build(BuildContext context) {
    return _Section(title: 'Men haqimda',
      child: Text(q.bio, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)));
  }
}


class _HoursBlock extends StatelessWidget {
  final Qassob q;
  const _HoursBlock({required this.q});

  // Localized weekday labels + ordering so Du-Ya renders consistently regardless of dict key
  // iteration order from the backend.
  static const _days = [
    ('mon', 'Dushanba'), ('tue', 'Seshanba'), ('wed', 'Chorshanba'), ('thu', 'Payshanba'),
    ('fri', 'Juma'), ('sat', 'Shanba'), ('sun', 'Yakshanba'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _Section(title: 'Ish vaqti',
      child: Column(children: _days.map((entry) {
        final code = entry.$1; final label = entry.$2;
        final h = q.workingHours[code];
        final closed = h == null;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: tt.bodyMedium)),
            Text(closed ? 'Dam'
                       : '${h[0].toString().padLeft(2, '0')}:00 – '
                         '${h[1].toString().padLeft(2, '0')}:00',
                style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: closed ? cs.onSurfaceVariant : cs.onSurface)),
          ]));
      }).toList()));
  }
}


class _PriceListBlock extends StatelessWidget {
  final Qassob q;
  const _PriceListBlock({required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _Section(title: 'Narxlar',
      child: Column(children: q.priceList.map((row) {
        return Container(margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant)),
          child: Row(children: [
            Expanded(child: Text(row.service,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            Text("${_fmt(row.priceUzs)} so'm / ${row.unit}",
                style: tt.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
          ]));
      }).toList()));
  }

  /// Integer thousands-separator formatter (UZS prices are always whole soms in this app — kopek
  /// granularity isn't used). 1234567 → "1 234 567".
  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}


class _CertificationsBlock extends StatelessWidget {
  final Qassob q;
  const _CertificationsBlock({required this.q});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _Section(title: 'Sertifikatlar',
      child: Column(children: q.certifications.map((c) {
        return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.verified_rounded, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(c.name, style: tt.bodyMedium)),
            if (c.year != null) Text(c.year.toString(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]));
      }).toList()));
  }
}


class _LanguageBlock extends StatelessWidget {
  final Qassob q;
  const _LanguageBlock({required this.q});

  static const _labels = {'uz': "O'zbekcha", 'ru': 'Русский', 'en': 'English', 'tg': 'Tojikcha'};

  @override
  Widget build(BuildContext context) {
    return _ChipSection(
      title: 'Tillar',
      items: q.languages.map((c) => _labels[c.toLowerCase()] ?? c).toList(),
      accent: const Color(0xFF1B5E20));
  }
}


class _ContactBlock extends StatelessWidget {
  final Qassob q;
  const _ContactBlock({required this.q});

  @override
  Widget build(BuildContext context) {
    final has = q.phone.isNotEmpty || q.telegram.isNotEmpty;
    if (!has) return const SizedBox.shrink();
    return _Section(title: "Bog'lanish",
      child: Column(children: [
        if (q.phone.isNotEmpty)
          _ContactRow(icon: Icons.phone_rounded, label: q.phone,
              onTap: () => launchUrl(Uri.parse('tel:${q.phone}'),
                  mode: LaunchMode.externalApplication)),
        if (q.telegram.isNotEmpty)
          _ContactRow(icon: Icons.telegram, label: '@${q.telegram.replaceFirst('@', '')}',
              onTap: () => launchUrl(
                  Uri.parse('https://t.me/${q.telegram.replaceFirst('@', '')}'),
                  mode: LaunchMode.externalApplication)),
      ]));
  }
}


class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: cs.primary),
      title: Text(label),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant));
  }
}


class _Pill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _Pill({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]));
  }
}


class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: cs.error)),
      ])));
  }
}
