// Riverpod providers for favorites — repo, list, and a set-of-listing-ids for fast O(1) "is this saved?" checks on cards.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/auth_state.dart';
import '../data/favorites_repository.dart';


final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) =>
    FavoritesRepository(ref.watch(apiClientProvider)));


/// Paginated list of the user's saved listings — used by the "Saved" screen in the Profile tab.
final favoritesListProvider = FutureProvider.autoDispose((ref) async =>
    ref.watch(favoritesRepositoryProvider).list());


/// Set of favorited listing IDs — used by individual cards to know whether to fill the heart.
/// Computed from the same fetch; falls back to empty when unauthenticated to avoid 401 spam.
final favoritedIdsProvider = FutureProvider<Set<int>>((ref) async {
  if (ref.watch(authNotifierProvider) is! AuthAuthenticated) return <int>{};
  final page = await ref.watch(favoritesRepositoryProvider).list();
  return page.results.map((f) => f.listing.id).toSet();
});
