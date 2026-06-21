import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// "Sharhlar" screen — list of reviews left for this partner.
/// Empty state shows a clear message (no spinner, no "null" leak).
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


class _ReviewCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> row;
  const _ReviewCard({required this.row});
  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}


class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _replying = false;
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _replyCtrl.text = (widget.row['reply_text'] as String?) ?? '';
  }

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _replying = true);
    try {
      await ref.read(apiClientProvider).dio.post(
        '/partner/reviews/${widget.row['id']}/reply/',
        data: {'reply_text': text});
      ref.invalidate(_reviewsProvider);
    } catch (_) {} finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = widget.row;
    final rating = (r['rating'] as num?)?.toInt() ?? 0;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r['buyer_name']?.toString() ?? '—',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          Row(mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) => Icon(
                  i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 18, color: const Color(0xFFEF9A00)))),
        ]),
        if ((r['comment'] as String?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          Text(r['comment'] as String,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
        ],
        const SizedBox(height: 12),
        TextField(controller: _replyCtrl,
          maxLines: 2,
          decoration: InputDecoration(hintText: t.ratingsReplyHint)),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: FilledButton(
          onPressed: _replying ? null : _sendReply,
          child: _replying
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(t.ratingsReplyAction))),
      ]));
  }
}
