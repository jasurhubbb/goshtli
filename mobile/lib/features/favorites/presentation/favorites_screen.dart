// FavoritesScreen — "Saqlangan e'lonlar" — reachable from Profile tab.
//
// Uses the same flat-card render as the search Tab's filtered view (we re-import it for visual consistency).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/favorites_providers.dart';


class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(favoritesListProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref..invalidate(favoritesListProvider)..invalidate(favoritedIdsProvider);
        },
        child: CustomScrollView(slivers: [
          SliverAppBar.large(title: const Text('Saved listings')),
          async.when(
            data: (page) => page.results.isEmpty
                ? SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite_border, size: 56, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('No saved listings yet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                    ])))
                : SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: page.results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final fav = page.results[i];
                        return Card(child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: ClipRRect(borderRadius: BorderRadius.circular(10),
                            child: fav.listing.primaryPhotoUrl == null
                                ? Container(width: 64, height: 64, color: cs.surfaceContainerHighest,
                                    child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant))
                                : Image.network(fav.listing.primaryPhotoUrl!, width: 64, height: 64,
                                    fit: BoxFit.cover, errorBuilder: (_, _, _) =>
                                        Container(width: 64, height: 64, color: cs.surfaceContainerHighest,
                                          child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant)))),
                          title: Text(fav.listing.title),
                          subtitle: Text('${fav.listing.pricePerKg.toStringAsFixed(0)} ${t.perKgSuffix}'
                                          '  ·  ${fav.listing.location}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/listings/${fav.listing.id}'),
                        ));
                      })),
            loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()))),
            error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24),
                child: Center(child: Text(t.failedPrefix(e.toString()))))),
          ),
        ]),
      ),
    );
  }
}
