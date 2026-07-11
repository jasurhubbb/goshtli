import 'package:dio/dio.dart';
import 'package:shared_core/shared_core.dart' show ApiClient;

import '../../../shared/utils/upload.dart';
import 'courier_models.dart';


/// Thin HTTP layer over the backend /couriers/* endpoints. Every method returns a strongly-typed
/// domain object so the UI never sees a `Map<String, dynamic>` directly.
class CourierRepository {
  final ApiClient _api;
  const CourierRepository(this._api);

  Future<CourierProfile?> me() async {
    final r = await _api.dio.get('/couriers/me/');
    if (r.statusCode == 200 && r.data is Map) {
      return CourierProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    return null;
  }

  /// PATCH /couriers/me/ — supports JSON or multipart. Callers pass a map of field → value; if a
  /// value is a MultipartFile it's assumed to be the photo upload.
  Future<CourierProfile> updateMe(Map<String, dynamic> data) async {
    final hasFile = data.values.any((v) => v is MultipartFile);
    final body = hasFile ? FormData.fromMap(data) : data;
    final options = hasFile ? Options(contentType: 'multipart/form-data') : null;
    final r = await _api.dio.patch('/couriers/me/', data: body, options: options);
    return CourierProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<bool> setOnline(bool online) async {
    final r = await _api.dio.post('/couriers/me/availability/',
        data: {'is_online': online});
    return (r.data is Map && r.data['is_online'] == true);
  }

  Future<CourierDashboard?> dashboard() async {
    final r = await _api.dio.get('/couriers/me/dashboard/');
    if (r.statusCode == 200 && r.data is Map) {
      return CourierDashboard.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    return null;
  }

  Future<List<DeliveryRow>> deliveries(String bucket) async {
    final r = await _api.dio.get('/couriers/me/deliveries/',
        queryParameters: {'bucket': bucket});
    final data = r.data;
    if (data is List) {
      return data.map((e) => DeliveryRow.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => DeliveryRow.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  Future<DeliveryDetail?> deliveryDetail(int id) async {
    final r = await _api.dio.get('/couriers/me/deliveries/$id/');
    if (r.statusCode == 200 && r.data is Map) {
      return DeliveryDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    return null;
  }

  Future<DeliveryDetail> advanceStatus(int id, DeliveryStatus to, {int? cashCollectedUzs}) async {
    final payload = <String, dynamic>{'status': deliveryStatusToWire(to)};
    if (cashCollectedUzs != null) payload['cash_collected_uzs'] = cashCollectedUzs;
    final r = await _api.dio.post('/couriers/me/deliveries/$id/status/', data: payload);
    return DeliveryDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Multipart upload of a photo proof. Used both after ARRIVED (as a "package at door" shot) and
  /// as an optional attachment after DELIVERED for dispute defense.
  Future<DeliveryDetail> uploadProof(int id, String filePath) async {
    final form = FormData.fromMap({
      'proof_photo': await multipartFromPath(filePath),
    });
    final r = await _api.dio.post('/couriers/me/deliveries/$id/proof/', data: form,
        options: Options(contentType: 'multipart/form-data'));
    return DeliveryDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<EarningsResult?> earnings({required String period}) async {
    final r = await _api.dio.get('/couriers/me/earnings/',
        queryParameters: {'period': period});
    if (r.statusCode == 200 && r.data is Map) {
      return EarningsResult.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    return null;
  }
}
