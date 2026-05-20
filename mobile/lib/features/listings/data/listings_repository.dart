// ListingsRepository — all /api/v1/listings/* calls. Maps DRF errors to ApiException for uniform UI handling.
//
// v3.1 catalog overhaul: browse() filters now match the new backend (category, market, region, q, status, price).
// The legacy meat_type / halal / cold_chain / service_area filters are gone.
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/paginated.dart';


class ApiException implements Exception {
  final String message;
  final Map<String, List<String>>? fieldErrors;
  const ApiException(this.message, [this.fieldErrors]);
  @override String toString() => message;
}


class ListingsRepository {
  final ApiClient _api;
  ListingsRepository(this._api);

  /// GET /listings/ — public browse. Backend defaults to ACTIVE-only when status param is omitted, so the
  /// Menyu tab hits this without thinking. Filters map 1:1 onto django-filter params in apps/listings/filters.py.
  Future<Paginated<Listing>> browse({
    String? category,       // category slug — e.g. "mol-goshti"
    String? market,         // market slug
    String? region,         // exact-match (case-insensitive) on Market.region
    String? status,         // omit → backend returns only ACTIVE
    double? priceMin,
    double? priceMax,
    String? q,              // free-text search across name_uz + name_ru
    String? ordering,       // e.g. "price_per_kg" or "-created_at"
    int page = 1,
  }) async {
    final r = await _api.dio.get('/listings/', queryParameters: {
      'page': page,
      if (category != null && category.isNotEmpty) 'category': category,
      if (market != null && market.isNotEmpty) 'market': market,
      if (region != null && region.isNotEmpty) 'region': region,
      if (status != null && status.isNotEmpty) 'status': status,
      if (priceMin != null) 'price_min': priceMin,
      if (priceMax != null) 'price_max': priceMax,
      if (q != null && q.isNotEmpty) 'q': q,
      if (ordering != null && ordering.isNotEmpty) 'ordering': ordering,
    });
    if (r.statusCode == 200) {
      return Paginated.fromJson(r.data as Map<String, dynamic>, Listing.fromJson);
    }
    throw _toApiException(r);
  }

  /// GET /listings/{id}/ — single product detail. Used when buyers tap a card to drill in.
  Future<Listing> getById(int id) async {
    final r = await _api.dio.get('/listings/$id/');
    if (r.statusCode == 200) return Listing.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// Normalize DRF error shapes (`{detail: "..."}` vs `{field: ["..."]}`) into a single ApiException.
  ApiException _toApiException(Response r) {
    final data = r.data;
    if (data is Map<String, dynamic>) {
      if (data['detail'] is String) return ApiException(data['detail'] as String);
      final fieldErrors = <String, List<String>>{};
      for (final entry in data.entries) {
        if (entry.value is List) {
          fieldErrors[entry.key] = (entry.value as List).map((e) => e.toString()).toList();
        }
      }
      return ApiException(fieldErrors.values.expand((v) => v).join('; '), fieldErrors);
    }
    return ApiException('Request failed (HTTP ${r.statusCode}).');
  }
}
