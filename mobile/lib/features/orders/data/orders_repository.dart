// OrdersRepository — every /api/v1/orders/* call. Backend errors are normalized into ApiException for screens to render.
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/order.dart' as model;
import '../../../shared/models/paginated.dart';
import '../../listings/data/listings_repository.dart' show ApiException;  // reuse the same exception shape


class OrdersRepository {
  final ApiClient _api;
  OrdersRepository(this._api);

  /// POST /orders/ — buyer places an order. Backend handles atomic stock decrement; we just hand it the listing id + qty.
  Future<model.Order> placeOrder({required int listingId, required double quantityKg,
                                  required String deliveryAddress, String notes = ''}) async {
    final r = await _api.dio.post('/orders/', data: {
      'listing': listingId, 'quantity_kg': quantityKg.toStringAsFixed(2),
      'delivery_address': deliveryAddress, 'notes': notes,
    });
    if (r.statusCode == 201) return model.Order.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// GET /orders/my/ — buyer-facing list of their own orders. Server enforces ownership.
  Future<Paginated<model.Order>> myOrders({int page = 1, model.OrderStatus? status}) async {
    final r = await _api.dio.get('/orders/my/', queryParameters: {
      'page': page,
      'status': ?_statusToWire(status),  // null-aware: param omitted unless caller passed a status filter
    });
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, model.Order.fromJson);
    throw _toApiException(r);
  }

  /// GET /orders/supplier/ — supplier-facing list of orders against their listings.
  Future<Paginated<model.Order>> supplierOrders({int page = 1, model.OrderStatus? status}) async {
    final r = await _api.dio.get('/orders/supplier/', queryParameters: {
      'page': page, 'status': ?_statusToWire(status),
    });
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, model.Order.fromJson);
    throw _toApiException(r);
  }

  /// GET /orders/{id}/ — readable by buyer or by the supplier of the listing; backend returns 404 to non-owners.
  Future<model.Order> getById(int id) async {
    final r = await _api.dio.get('/orders/$id/');
    if (r.statusCode == 200) return model.Order.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// POST /orders/{id}/cancel/ — buyer-side cancellation (PENDING only). Backend restores stock atomically.
  Future<model.Order> cancelAsBuyer(int id) async {
    final r = await _api.dio.post('/orders/$id/cancel/');
    if (r.statusCode == 200) return model.Order.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// POST /orders/supplier/{id}/status/ — supplier drives the state machine (CONFIRMED/PROCESSING/IN_TRANSIT/DELIVERED/CANCELLED).
  Future<model.Order> setSupplierStatus(int id, model.OrderStatus status) async {
    final r = await _api.dio.post('/orders/supplier/$id/status/', data: {'status': _statusToWire(status)});
    if (r.statusCode == 200) return model.Order.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// Mirror of OrderStatus enum → backend wire string.
  static String? _statusToWire(model.OrderStatus? s) => s == null ? null : switch (s) {
    model.OrderStatus.pending => 'PENDING', model.OrderStatus.confirmed => 'CONFIRMED',
    model.OrderStatus.processing => 'PROCESSING', model.OrderStatus.inTransit => 'IN_TRANSIT',
    model.OrderStatus.delivered => 'DELIVERED', model.OrderStatus.cancelled => 'CANCELLED',
  };

  ApiException _toApiException(Response r) {
    if (r.data is Map<String, dynamic>) {
      final m = r.data as Map<String, dynamic>;
      if (m['detail'] is String) return ApiException(m['detail'] as String);
      final field = <String, List<String>>{};
      m.forEach((k, v) { if (v is List) field[k] = v.map((e) => e.toString()).toList(); });
      return ApiException(field.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n'), field);
    }
    if (r.data is List && (r.data as List).isNotEmpty) return ApiException((r.data as List).first.toString());
    return ApiException('Request failed (HTTP ${r.statusCode})');
  }
}
