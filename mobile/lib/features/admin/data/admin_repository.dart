// AdminRepository — admin-only HTTP calls used by the in-app /admin page.
//
// Critical wiring: this repo uses AdminApiClient (NOT the main ApiClient). All admin requests carry the
// admin JWT from AdminTokenStorage, not the main app's user token. That isolation is what lets a buyer
// stay logged into the main app while admin operates in parallel.
//
// Scope (v3.3):
//   • listSuppliers()         → GET  /suppliers/list/        (kept for future use; not in the UI right now)
//   • patchSupplier(...)      → PATCH /suppliers/<id>/        (admin can flip is_verified)
//   • listCategories()        → GET  /categories/?include_inactive=1
//   • createCategory(...)     → POST /categories/
//   • patchCategory(...)      → PATCH /categories/<id>/
//   • deleteCategory(id)      → DELETE /categories/<id>/      (soft-archive)
//   • listMarkets()           → GET  /markets/?include_inactive=1
//   • createMarket(...)       → POST /markets/                (auto-creates the backing supplier user server-side)
//   • patchMarket(...)        → PATCH /markets/<id>/
//   • deleteMarket(id)        → DELETE /markets/<id>/         (soft-archive)
//   • getMarket(id)           → GET  /markets/<id>/           (single read for the Bozor detail screen)
//   • createListing(...)      → POST /listings/               (supplier resolved server-side from market.owner_user)
//   • uploadListingPhoto(...) → POST /listings/<id>/photos/   (multipart; admin bypass on ownership)
import 'package:dio/dio.dart';

import '../../../shared/models/supplier_profile.dart';
import '../../listings/data/listings_repository.dart';
import 'admin_api_client.dart';
import 'admin_models.dart';


class AdminRepository {
  final AdminApiClient _api;
  AdminRepository(this._api);

  // ---------- Suppliers ----------

  Future<List<SupplierProfile>> listSuppliers() async {
    final r = await _api.dio.get('/suppliers/list/');
    if (r.statusCode == 200) {
      // The backend returns a list (no pagination wrapper) — keep parsing simple.
      final raw = r.data is List ? r.data as List : (r.data['results'] as List? ?? const []);
      return raw.map((e) => SupplierProfile.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _toErr(r);
  }

  Future<SupplierProfile> patchSupplier(int id, {String? businessName, String? region,
      String? address, bool? isVerified}) async {
    final r = await _api.dio.patch('/suppliers/$id/', data: {
      'business_name': ?businessName, 'region': ?region, 'address': ?address,
      'is_verified': ?isVerified,
    });
    if (r.statusCode == 200) return SupplierProfile.fromJson(r.data as Map<String, dynamic>);
    throw _toErr(r);
  }

  // ---------- Categories ----------

  Future<List<AdminCategory>> listCategories() async {
    // include_inactive=1 — admin needs to see archived categories so they can flip them back on.
    final r = await _api.dio.get('/categories/', queryParameters: {'include_inactive': '1'});
    if (r.statusCode == 200) {
      final raw = r.data is List ? r.data as List : (r.data['results'] as List? ?? const []);
      return raw.map((e) => AdminCategory.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _toErr(r);
  }

  Future<AdminCategory> createCategory({required String nameUz, required String nameRu,
      int displayOrder = 100}) async {
    final r = await _api.dio.post('/categories/', data: {
      'name_uz': nameUz, 'name_ru': nameRu, 'display_order': displayOrder, 'is_active': true,
    });
    if (r.statusCode == 201) return AdminCategory.fromJson(r.data as Map<String, dynamic>);
    throw _toErr(r);
  }

  Future<AdminCategory> patchCategory(int id, {String? nameUz, String? nameRu,
      int? displayOrder, bool? isActive}) async {
    final r = await _api.dio.patch('/categories/$id/', data: {
      'name_uz': ?nameUz, 'name_ru': ?nameRu,
      'display_order': ?displayOrder, 'is_active': ?isActive,
    });
    if (r.statusCode == 200) return AdminCategory.fromJson(r.data as Map<String, dynamic>);
    throw _toErr(r);
  }

  Future<void> deleteCategory(int id) async {
    final r = await _api.dio.delete('/categories/$id/');
    if (r.statusCode != 204) throw _toErr(r);
  }

  // ---------- Markets ----------

  Future<List<AdminMarket>> listMarkets() async {
    final r = await _api.dio.get('/markets/', queryParameters: {'include_inactive': '1'});
    if (r.statusCode == 200) {
      final raw = r.data is List ? r.data as List : (r.data['results'] as List? ?? const []);
      return raw.map((e) => AdminMarket.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _toErr(r);
  }

  Future<AdminMarket> createMarket({required String nameUz, required String nameRu,
      required String region, required String address, String phone = ''}) async {
    final r = await _api.dio.post('/markets/', data: {
      'name_uz': nameUz, 'name_ru': nameRu,
      'region': region, 'address': address,
      // phone is optional but always send the key — empty string explicitly clears it on the server side.
      'phone': phone, 'is_active': true,
    });
    if (r.statusCode == 201) return AdminMarket.fromJson(r.data as Map<String, dynamic>);
    throw _toErr(r);
  }

  Future<AdminMarket> patchMarket(int id, {String? nameUz, String? nameRu,
      String? region, String? address, String? phone, bool? isActive}) async {
    final r = await _api.dio.patch('/markets/$id/', data: {
      'name_uz': ?nameUz, 'name_ru': ?nameRu, 'region': ?region, 'address': ?address,
      'phone': ?phone, 'is_active': ?isActive,
    });
    if (r.statusCode == 200) return AdminMarket.fromJson(r.data as Map<String, dynamic>);
    throw _toErr(r);
  }

  /// GET /markets/<id>/ — single-market read for the Bozor detail screen.
  Future<AdminMarket> getMarket(int id) async {
    final r = await _api.dio.get('/markets/$id/');
    if (r.statusCode == 200) return AdminMarket.fromJson(r.data as Map<String, dynamic>);
    throw _toErr(r);
  }

  Future<void> deleteMarket(int id) async {
    final r = await _api.dio.delete('/markets/$id/');
    if (r.statusCode != 204) throw _toErr(r);
  }

  // ---------- Listings ----------

  /// Admin creates a listing for a specific Market. Backend (v3.3) resolves Listing.supplier from
  /// Market.owner_user when the caller (admin) doesn't pass supplier_id explicitly, so the in-app admin
  /// only picks a Market — no separate supplier concept exists in the UI. available_from defaults to
  /// today server-side; the admin form doesn't ask for it.
  Future<Map<String, dynamic>> createListing({required int marketId, required int categoryId,
      required String nameUz, required String nameRu,
      required double quantityKg, required double pricePerKg,
      String location = '', String descriptionUz = '', String descriptionRu = ''}) async {
    final r = await _api.dio.post('/listings/', data: {
      'market_id': marketId, 'category_id': categoryId,
      'name_uz': nameUz, 'name_ru': nameRu,
      if (descriptionUz.isNotEmpty) 'description_uz': descriptionUz,
      if (descriptionRu.isNotEmpty) 'description_ru': descriptionRu,
      // Backend stores quantity/price as Decimal — pass as strings to avoid float rounding (matches existing wire format)
      'quantity_kg': quantityKg.toString(), 'price_per_kg': pricePerKg.toString(),
      'location': location,
      // available_from omitted — server fills today() via ListingSerializer.validate
    });
    if (r.statusCode == 201) return r.data as Map<String, dynamic>;
    throw _toErr(r);
  }

  /// POST /listings/<listing_pk>/photos/ — multipart upload for one image. Admin bypass on the backend
  /// means we can attach photos to any listing once createListing has returned the new id.
  Future<void> uploadListingPhoto(int listingId, String filePath) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
    });
    final r = await _api.dio.post('/listings/$listingId/photos/', data: form);
    if (r.statusCode != 201) throw _toErr(r);
  }

  ApiException _toErr(Response r) {
    final data = r.data;
    if (data is Map<String, dynamic>) {
      if (data['detail'] is String) return ApiException(data['detail'] as String);
      final fieldErrors = <String, List<String>>{};
      for (final e in data.entries) {
        if (e.value is List) fieldErrors[e.key] = (e.value as List).map((x) => x.toString()).toList();
      }
      return ApiException(fieldErrors.values.expand((v) => v).join('; '), fieldErrors);
    }
    return ApiException('Request failed (HTTP ${r.statusCode}).');
  }
}
