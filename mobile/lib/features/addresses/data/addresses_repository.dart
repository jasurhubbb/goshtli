// AddressesRepository — wraps /api/v1/buyers/addresses/ CRUD. Authenticated-only; the API gates by auth class.
//
// Anonymous users can't save addresses (they hit 401), so the UI layer must check auth state before invoking
// any of these. Errors are returned as the same ApiException shape used elsewhere for uniform handling.
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../listings/data/listings_repository.dart' show ApiException;
import 'address_model.dart';


class AddressesRepository {
  final ApiClient _api;
  AddressesRepository(this._api);

  /// GET /buyers/addresses/ — list the current user's saved addresses. Returns [] for new users.
  /// DRF returns either a paginated envelope or a bare list depending on the viewset; we handle both.
  Future<List<Address>> list() async {
    final r = await _api.dio.get('/buyers/addresses/');
    if (r.statusCode != 200) throw _toApiException(r);
    final data = r.data;
    final items = (data is Map<String, dynamic> && data['results'] is List)
        ? data['results'] as List
        : (data is List ? data : <Object>[]);
    return items.map((j) => Address.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// POST /buyers/addresses/ — create a new address. Returns the created row including its server-assigned id.
  Future<Address> create({required String label, required String address,
                          String entrance = '', String floor = '', String apartment = '', String notes = '',
                          double? lat, double? lng, bool isDefault = false}) async {
    final r = await _api.dio.post('/buyers/addresses/', data: {
      'label': label, 'address': address,
      'entrance': entrance, 'floor': floor, 'apartment': apartment, 'notes': notes,
      if (lat != null) 'lat': lat.toStringAsFixed(6),
      if (lng != null) 'lng': lng.toStringAsFixed(6),
      'is_default': isDefault,
    });
    if (r.statusCode == 201) return Address.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// PATCH /buyers/addresses/{id}/ — partial update. Pass only the fields that changed.
  Future<Address> update(int id, Map<String, dynamic> patch) async {
    final r = await _api.dio.patch('/buyers/addresses/$id/', data: patch);
    if (r.statusCode == 200) return Address.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// DELETE /buyers/addresses/{id}/ — hard delete; the row is gone after this. Server returns 204.
  Future<void> delete(int id) async {
    final r = await _api.dio.delete('/buyers/addresses/$id/');
    if (r.statusCode != 204) throw _toApiException(r);
  }

  ApiException _toApiException(Response r) {
    final data = r.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return ApiException(data['detail'] as String);
    }
    return ApiException('Request failed (HTTP ${r.statusCode}).');
  }
}
