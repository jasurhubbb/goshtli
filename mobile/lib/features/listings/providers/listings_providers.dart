// Riverpod providers for listings — repository plus async data providers used by screens.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/models/paginated.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/listings_repository.dart';


final listingsRepositoryProvider = Provider<ListingsRepository>((ref) => ListingsRepository(ref.watch(apiClientProvider)));


/// Filter state for the browse screen — held as a record so edits trigger provider re-evaluation cleanly.
typedef ListingFilters = ({String? meatType, String? location, double? priceMin, double? priceMax,
                           String? search, String? ordering});

final listingFiltersProvider = StateProvider<ListingFilters>((ref) =>
    (meatType: null, location: null, priceMin: null, priceMax: null, search: null, ordering: '-created_at'));


/// Browse provider — auto-refetches whenever filters change. Used by ListingsScreen.
final listingsBrowseProvider = FutureProvider.autoDispose<Paginated<Listing>>((ref) async {
  final f = ref.watch(listingFiltersProvider);
  return ref.watch(listingsRepositoryProvider).browse(meatType: f.meatType, location: f.location,
      priceMin: f.priceMin, priceMax: f.priceMax, search: f.search, ordering: f.ordering);
});


/// "My listings" provider — supplier-only. autoDispose ensures the cache is fresh after add/edit/delete.
final myListingsProvider = FutureProvider.autoDispose<Paginated<Listing>>((ref) async =>
    ref.watch(listingsRepositoryProvider).myListings());


/// Single listing — keyed by id. Used by detail screen and order placement flow.
final listingByIdProvider = FutureProvider.autoDispose.family<Listing, int>((ref, id) async =>
    ref.watch(listingsRepositoryProvider).getById(id));
