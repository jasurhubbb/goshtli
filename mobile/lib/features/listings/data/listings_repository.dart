// ListingsRepository — all /api/v1/listings/* calls. Maps DRF errors to ApiException for uniform UI handling.
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

  /// GET /listings/ — public browse. v2 adds halal_certified / cold_chain / service_area / verified_only filters.
  /// Backend hides INACTIVE/SOLD_OUT unless we send ?status= explicitly.
  Future<Paginated<Listing>> browse({String? meatType, String? location, double? priceMin, double? priceMax,
                                     String? search, String? ordering, int page = 1,
                                     bool? halalOnly, String? coldChain, String? serviceArea,
                                     bool? verifiedOnly}) async {
    final r = await _api.dio.get('/listings/', queryParameters: {
      'page': page,
      'meat_type': ?meatType,
      if (location != null && location.isNotEmpty) 'location': location,
      'price_min': ?priceMin,
      'price_max': ?priceMax,
      if (search != null && search.isNotEmpty) 'search': search,
      'ordering': ?ordering,
      // v2 filters — only send when the user has actually toggled them, so the backend can stay efficient
      'halal_certified': ?halalOnly,
      'cold_chain': ?coldChain,
      if (serviceArea != null && serviceArea.isNotEmpty) 'service_area': serviceArea,
      'verified_only': ?verifiedOnly,
    });
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, Listing.fromJson);
    throw _toApiException(r);
  }

  /// GET /listings/my/ — supplier's own listings (all statuses, including INACTIVE/SOLD_OUT).
  Future<Paginated<Listing>> myListings({int page = 1}) async {
    final r = await _api.dio.get('/listings/my/', queryParameters: {'page': page});
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, Listing.fromJson);
    throw _toApiException(r);
  }

  /// GET /listings/{id}/ — public read; auth required only for unsafe methods.
  Future<Listing> getById(int id) async {
    final r = await _api.dio.get('/listings/$id/');
    if (r.statusCode == 200) return Listing.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// POST /listings/ — verified supplier only. v2 adds halal/freshness/cold-chain/service-area fields.
  /// Server enforces verification; we pre-check on the client to fail fast.
  Future<Listing> create({required String title, required MeatType meatType, required double quantityKg,
                          required double pricePerKg, required String location, required String availableFrom,
                          String description = '', bool halalCertified = false, String? freshnessDate,
                          ColdChain coldChain = ColdChain.fresh, String serviceAreaCsv = ''}) async {
    final r = await _api.dio.post('/listings/', data: {
      'title': title, 'meat_type': _meatTypeToWire(meatType), 'quantity_kg': quantityKg.toStringAsFixed(2),
      'price_per_kg': pricePerKg.toStringAsFixed(2), 'location': location, 'available_from': availableFrom,
      'description': description,
      'halal_certified': halalCertified,
      'freshness_date': ?freshnessDate,         // null-aware: only send if caller provided one
      'cold_chain': _coldChainToWire(coldChain),
      'service_area_csv': serviceAreaCsv,
    });
    if (r.statusCode == 201) return Listing.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// ColdChain → backend wire string. Mirrors backend Listing.ColdChain enum values.
  static String _coldChainToWire(ColdChain c) => switch (c) {
    ColdChain.fresh => 'FRESH', ColdChain.chilled => 'CHILLED', ColdChain.frozen => 'FROZEN',
  };

  /// POST /listings/{id}/photos/ — multipart upload. Returns the photo URL+id; reload the listing for the new gallery.
  /// File is uploaded under the form key 'image' so it matches the DRF MultiPartParser on the backend.
  Future<void> uploadPhoto(int listingId, String filePath) async {
    final form = FormData.fromMap({'image': await MultipartFile.fromFile(filePath)});
    final r = await _api.dio.post('/listings/$listingId/photos/', data: form);
    if (r.statusCode != 201) throw _toApiException(r);
  }

  /// PATCH /listings/{id}/ — owner only. Used for price/desc/status edits.
  Future<Listing> update(int id, Map<String, dynamic> changes) async {
    final r = await _api.dio.patch('/listings/$id/', data: changes);
    if (r.statusCode == 200) return Listing.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// DELETE /listings/{id}/ — owner only. Backend rejects with 403 if any orders are attached (set INACTIVE instead).
  Future<void> delete(int id) async {
    final r = await _api.dio.delete('/listings/$id/');
    if (r.statusCode != 204) throw _toApiException(r);
  }

  /// MeatType → backend enum string. Keeps the wire format in one place.
  static String _meatTypeToWire(MeatType t) => switch (t) {
    MeatType.beef => 'BEEF', MeatType.mutton => 'MUTTON', MeatType.chicken => 'CHICKEN',
    MeatType.goat => 'GOAT', MeatType.horse => 'HORSE', MeatType.other => 'OTHER',
  };

  ApiException _toApiException(Response r) {
    if (r.data is Map<String, dynamic>) {
      final m = r.data as Map<String, dynamic>;
      if (m['detail'] is String) return ApiException(m['detail'] as String);
      final field = <String, List<String>>{};
      m.forEach((k, v) { if (v is List) field[k] = v.map((e) => e.toString()).toList(); });
      return ApiException(field.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n'), field);
    }
    return ApiException('Request failed (HTTP ${r.statusCode})');
  }
}
