// FavoritesRepository — calls /api/v1/favorites/*. Toggle returns 200/201 for add and 204 for remove.
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/paginated.dart';
import '../../listings/data/listings_repository.dart' show ApiException;


/// A Favorite is essentially a wrapped Listing + the favorite row id. We embed the full Listing so saved-screen
/// rendering doesn't need a second round-trip.
class Favorite {
  final int id;
  final Listing listing;
  const Favorite({required this.id, required this.listing});

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        id: json['id'] as int,
        listing: Listing.fromJson(json['listing'] as Map<String, dynamic>));
}


class FavoritesRepository {
  final ApiClient _api;
  FavoritesRepository(this._api);

  Future<Paginated<Favorite>> list() async {
    final r = await _api.dio.get('/favorites/');
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, Favorite.fromJson);
    throw _err(r);
  }

  /// Idempotent — POST returns 200 if the favorite already existed.
  Future<void> add(int listingId) async {
    final r = await _api.dio.post('/favorites/$listingId/');
    if (r.statusCode != 200 && r.statusCode != 201) throw _err(r);
  }

  Future<void> remove(int listingId) async {
    final r = await _api.dio.delete('/favorites/$listingId/');
    if (r.statusCode != 204) throw _err(r);
  }

  ApiException _err(Response r) => ApiException(r.data is Map && (r.data as Map)['detail'] is String
      ? (r.data as Map)['detail'] as String : 'HTTP ${r.statusCode}');
}
