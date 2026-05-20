// Riverpod providers for listings — repository + async data providers used by screens.
//
// v3.1 catalog overhaul:
//   • `activeListingsProvider`  → buyer-facing feed for the Menyu home grid. Cached per locale/filter combo.
//   • `listingByIdProvider`     → single product detail; the listing detail screen reads this.
//   • `listingFiltersProvider`  → simple record exposed for future filter UIs (category, region, q, price).
//
// All complex legacy filters (meat_type, halal, cold_chain, service_area, verified_only) have been removed —
// see backend apps/listings/filters.py for the new query-param surface.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/models/paginated.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/listings_repository.dart';


final listingsRepositoryProvider =
    Provider<ListingsRepository>((ref) => ListingsRepository(ref.watch(apiClientProvider)));


/// Filter state — record type so toggle widgets update cheaply (no class boilerplate).
typedef ListingFilters = ({
  String? category,
  String? market,
  String? region,
  double? priceMin,
  double? priceMax,
  String? q,
  String? ordering,
});


final listingFiltersProvider = StateProvider<ListingFilters>((ref) =>
    (category: null, market: null, region: null, priceMin: null, priceMax: null, q: null, ordering: '-created_at'));


/// copyWith for the record — pass only the fields you want to change.
/// Wrappers-as-functions distinguish "no change" (null) from "set to null" (() => null).
extension ListingFiltersCopy on ListingFilters {
  ListingFilters copyWith({
    String? Function()? category, String? Function()? market, String? Function()? region,
    double? Function()? priceMin, double? Function()? priceMax,
    String? Function()? q, String? Function()? ordering,
  }) => (
    category: category == null ? this.category : category(),
    market: market == null ? this.market : market(),
    region: region == null ? this.region : region(),
    priceMin: priceMin == null ? this.priceMin : priceMin(),
    priceMax: priceMax == null ? this.priceMax : priceMax(),
    q: q == null ? this.q : q(),
    ordering: ordering == null ? this.ordering : ordering(),
  );
}


/// All ACTIVE listings (status omitted in the query → backend defaults to ACTIVE only).
/// Watched by the Menyu home screen. Pagination is single-page for v3.1; add infinite-scroll later when the
/// catalog grows past one page (current backend pagination is 20 / page).
final activeListingsProvider = FutureProvider<Paginated<Listing>>((ref) async {
  final repo = ref.watch(listingsRepositoryProvider);
  final f = ref.watch(listingFiltersProvider);
  return repo.browse(
    category: f.category, market: f.market, region: f.region,
    priceMin: f.priceMin, priceMax: f.priceMax,
    q: f.q, ordering: f.ordering,
  );
});


/// Single-product detail provider — keyed by id so multiple detail screens cache independently.
final listingByIdProvider =
    FutureProvider.family<Listing, int>((ref, id) => ref.watch(listingsRepositoryProvider).getById(id));
