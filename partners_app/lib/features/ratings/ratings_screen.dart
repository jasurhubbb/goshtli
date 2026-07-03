import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// "Sharhlar" screen — read-only list of reviews left for this partner.
///
/// v3.9.13 — dropped the reply text field + Send button. Partners kept ignoring the reply feature
/// (it's a lot of typing for little payoff, and buyers don't check back for a reply anyway), so
/// the card is now a pure "who said what" summary. Backend /reply endpoint stays wired in case we
/// bring the surface back for select partner tiers later.
class RatingsScreen extends ConsumerWidget {
  const RatingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(_reviewsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop()),
        title: Text(t.ratingsTitle)),
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(_reviewsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(physics: const AlwaysScrollableScrollPhysics(),
            children: [Padding(padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
              child: Center(child: Text(t.ratingsEmpty,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center)))]),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(physics: const AlwaysScrollableScrollPhysics(),
                children: [Padding(padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
                  child: Column(children: [
                    Icon(Icons.star_border_rounded, size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(t.ratingsEmpty,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center),
                  ]))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: rows.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ReviewCard(row: rows[i]));
          },
        )),
    );
  }
}


/// Defensive parse — backend may return a bare list or a paginated `{results: [...]}` envelope, or an
/// empty `{count: 0}` shape on no data. All collapsed to a List<Map>.
final _reviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final r = await ref.read(apiClientProvider).dio.get('/partner/reviews/incoming/');
    final data = r.data;
    if (data is Map) {
      final raw = data['results'];
      if (raw is List) return raw.cast<Map<String, dynamic>>();
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  } catch (_) {
    return const [];
  }
});


class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ReviewCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rating = (row['rating'] as num?)?.toInt() ?? 0;
    final comment = (row['comment'] as String?) ?? '';
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(row['buyer_name']?.toString() ?? '—',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          Row(mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) => Icon(
                  i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 18, color: const Color(0xFFEF9A00)))),
        ]),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comment, style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
        ],
      ]));
  }
}
