// Riverpod providers for listings — repository plus async data providers used by screens.
//
// v2 adds halal / cold chain / service area / verified-only filters. Filter state stays as a record so individual
// toggle widgets can pattern-match + reconstruct without a full StateNotifier class.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/models/paginated.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/listings_repository.dart';


final listingsRepositoryProvider = Provider<ListingsRepository>((ref) => ListingsRepository(ref.watch(apiClientProvider)));


/// Filter state for browse screen — record type so listening + updating is cheap (no class boilerplate).
typedef ListingFilters = ({String? meatType, String? location, double? priceMin, double? priceMax,
                           String? search, String? ordering,
                           bool? halalOnly, String? coldChain, String? serviceArea, bool? verifiedOnly});

final listingFiltersProvider = StateProvider<ListingFilters>((ref) =>
    (meatType: null, location: null, priceMin: null, priceMax: null, search: null, ordering: '-created_at',
     halalOnly: null, coldChain: null, serviceArea: null, verifiedOnly: null));


/// copyWith for the ListingFilters record — pass only the fields you want to change.
/// Dart records don't have built-in copyWith; this hides the field-listing boilerplate from each call site.
extension ListingFiltersCopy on ListingFilters {
  ListingFilters copyWith({String? Function()? meatType, String? Function()? location,
                           double? Function()? priceMin, double? Function()? priceMax,
                           String? Function()? search, String? Function()? ordering,
                           bool? Function()? halalOnly, String? Function()? coldChain,
                           String? Function()? serviceArea, bool? Function()? verifiedOnly}) {
    // Wrappers as functions let us distinguish "no change" (null) from "set to null" (() => null).
    return (
      meatType: meatType == null ? this.meatType : meatType(),
      location: location == null ? this.location : location(),
      priceMin: priceMin == null ? this.priceMin : priceMin(),
      priceMax: priceMax == null ? this.priceMax : priceMax(),
      search: search == null ? this.search : search(),
      ordering: ordering == null ? this.ordering : ordering(),
      halalOnly: halalOnly == null ? this.halalOnly : halalOnly(),
      coldChain: coldChain == null ? this.coldChain : coldChain(),
      serviceArea: serviceArea == null ? this.serviceArea : serviceArea(),
      verifiedOnly: verifiedOnly == null ? this.verifiedOnly : verifiedOnly(),
    );
  }
}


/// Browse provider — auto-refetches whenever any filter field changes.
final listingsBrowseProvider = FutureProvider.autoDispose<Paginated<Listing>>((ref) async {
  final f = ref.watch(listingFiltersProvider);
  return ref.watch(listingsRepositoryProvider).browse(
      meatType: f.meatType, location: f.location, priceMin: f.priceMin, priceMax: f.priceMax,
      search: f.search, ordering: f.ordering,
      halalOnly: f.halalOnly, coldChain: f.coldChain, serviceArea: f.serviceArea, verifiedOnly: f.verifiedOnly);
});


/// "My listings" provider — supplier-only. autoDispose ensures the cache is fresh after add/edit/delete.
final myListingsProvider = FutureProvider.autoDispose<Paginated<Listing>>((ref) async =>
    ref.watch(listingsRepositoryProvider).myListings());


/// Single listing — keyed by id. Used by detail screen and order placement flow.
final listingByIdProvider = FutureProvider.autoDispose.family<Listing, int>((ref, id) async =>
    ref.watch(listingsRepositoryProvider).getById(id));
