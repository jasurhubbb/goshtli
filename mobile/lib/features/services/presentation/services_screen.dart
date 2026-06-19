import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../data/qassob_models.dart';
import '../providers/services_providers.dart';


/// Servislar tab — two sections: Qassoblar + Qushxona xizmatlari. Each is a horizontal carousel.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filter = ref.watch(servicesAnimalFilterProvider);
    final all = ref.watch(qassobsListProvider);
    final slaughter = ref.watch(slaughterhouseListProvider);

    final filters = [('', t.servicesFilterAll), ('MOL', 'Mol'),
                      ('QOY', "Qo'y"), ('ECHKI', 'Echki'), ('OT', 'Ot')];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(qassobsListProvider);
        ref.invalidate(slaughterhouseListProvider);
      },
      child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        SizedBox(height: 48,
          child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: filters.map((f) {
              final on = f.$1 == filter;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: on,
                  onSelected: (_) => ref.read(servicesAnimalFilterProvider.notifier).state = f.$1,
                  selectedColor: cs.primary,
                  labelStyle: TextStyle(color: on ? cs.onPrimary : cs.onSurface,
                      fontWeight: FontWeight.w700),
                ));
            }).toList())),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(t.servicesQassobs,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
        _Carousel(async: all),
        const SizedBox(height: 24),
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(t.servicesSlaughterhouses,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
        _Carousel(async: slaughter),
        const SizedBox(height: 24),
      ]),
    );
  }
}


class _Carousel extends StatelessWidget {
  final AsyncValue<List<Qassob>> async;
  const _Carousel({required this.async});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return SizedBox(height: 220, child: async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(child: Text(t.servicesNoneFound,
              style: TextStyle(color: cs.onSurfaceVariant)));
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: rows.length,
          separatorBuilder: (ctx, i) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _QassobCard(q: rows[i]));
      },
    ));
  }
}


class _QassobCard extends StatelessWidget {
  final Qassob q;
  const _QassobCard({required this.q});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(width: 240,
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 110,
          decoration: BoxDecoration(color: cs.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: q.photoUrl.isNotEmpty
              ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(q.photoUrl, fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (a, b, c) => Icon(Icons.store_rounded, color: cs.onSurfaceVariant, size: 40)))
              : Center(child: Icon(Icons.store_rounded, color: cs.onSurfaceVariant, size: 40))),
        Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.fullName, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${q.region}${q.distanceKm != null ? ' · ${q.distanceKm!.toStringAsFixed(1)} km' : ''}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.star_rounded, size: 16, color: const Color(0xFFEF9A00)),
              const SizedBox(width: 2),
              Text(q.ratingCount > 0 ? q.ratingAvg.toStringAsFixed(1) : '—',
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              if (q.yearsExperience > 0) ...[
                const SizedBox(width: 10),
                Text(t.servicesYearsExp(q.yearsExperience),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ]),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => _contact(context, q),
              child: Text(t.servicesContact))),
          ]))]));
  }

  Future<void> _contact(BuildContext context, Qassob q) async {
    if (q.telegram.isNotEmpty) {
      final h = q.telegram.replaceFirst('@', '');
      await launchUrl(Uri.parse('https://t.me/$h'),
          mode: LaunchMode.externalApplication);
      return;
    }
    if (q.phone.isNotEmpty) {
      await launchUrl(Uri.parse('tel:${q.phone}'),
          mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).servicesNoneFound)));
    }
  }
}
