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

  /// POST /orders/ with full v3.6 delivery + butcher params. Called from the Delivery page after the
  /// buyer's chosen a vehicle + time slot + butcher option. Backend wraps stock decrement + delivery/
  /// butcher persistence in a single atomic transaction (see apps/orders/services.create_order).
  Future<model.Order> placeOrderWithDelivery({
    required int listingId,
    required double quantityKg,
    required String deliveryAddress,
    String notes = '',
    required String deliveryVehicleType,           // "REFRIGERATOR" / "CHORVA_TAXI"
    required String deliveryTimeSlot,              // "SLOT_0609" / "SLOT_0913" / "SLOT_1318"
    required double deliveryDistanceKm,
    double? deliveryLat, double? deliveryLng,
    required double deliveryPrice,
    required bool butcherServiceRequested,
    required double butcherServiceFee,
    // v3.9.15 — buyer's picked qassob for live-animal orders. Only sent when butcherServiceRequested
    // is true; the backend soft-reserves this qassob for the first ~60s of dispatch before fanning
    // the job out.
    int? preferredQassobId,
  }) async {
    final r = await _api.dio.post('/orders/', data: {
      'listing': listingId, 'quantity_kg': quantityKg.toStringAsFixed(2),
      'delivery_address': deliveryAddress, 'notes': notes,
      'delivery_vehicle_type': deliveryVehicleType,
      'delivery_time_slot': deliveryTimeSlot,
      'delivery_distance_km': deliveryDistanceKm.toStringAsFixed(2),
      if (deliveryLat != null) 'delivery_lat': deliveryLat.toStringAsFixed(6),
      if (deliveryLng != null) 'delivery_lng': deliveryLng.toStringAsFixed(6),
      'delivery_price': deliveryPrice.toStringAsFixed(2),
      'butcher_service_requested': butcherServiceRequested,
      'butcher_service_fee': butcherServiceFee.toStringAsFixed(2),
      if (preferredQassobId != null && butcherServiceRequested)
        'preferred_qassob': preferredQassobId,
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

  /// v3.9.14 — POST /orders/{id}/confirm-delivery/ — buyer confirms receipt. Only valid from
  /// DELIVERED_PENDING_CONFIRMATION; backend rejects other states with 400.
  Future<model.Order> confirmDelivery(int id) async {
    final r = await _api.dio.post('/orders/$id/confirm-delivery/');
    if (r.statusCode == 200) return model.Order.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// POST /orders/supplier/{id}/status/ — supplier drives the state machine (CONFIRMED/PROCESSING/IN_TRANSIT/DELIVERED/CANCELLED).
  Future<model.Order> setSupplierStatus(int id, model.OrderStatus status) async {
    final r = await _api.dio.post('/orders/supplier/$id/status/', data: {'status': _statusToWire(status)});
    if (r.statusCode == 200) return model.Order.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  // ---------- v3.5 Payments ----------

  /// POST /payments/orders/<id>/pay/ — ask the backend to mint a fresh pay-link for this order.
  /// Returns the URL the WebView should open + the current payment_status (UNPAID|PENDING|PAID|FAILED).
  /// We hit this every time the user taps "Buyurtma berish" or "Qaytadan urinish" — the URL is one-shot
  /// so we always want a new one, not a cached value.
  Future<({String paymentUrl, String paymentStatus, String provider})> generatePayLink(int orderId) async {
    final r = await _api.dio.post('/payments/orders/$orderId/pay/');
    if (r.statusCode == 200) {
      final d = r.data as Map<String, dynamic>;
      return (
        paymentUrl: d['payment_url'] as String,
        paymentStatus: d['payment_status'] as String,
        provider: d['provider'] as String,
      );
    }
    throw _toApiException(r);
  }

  /// Mirror of OrderStatus enum → backend wire string.
  static String? _statusToWire(model.OrderStatus? s) => s == null ? null : switch (s) {
    model.OrderStatus.pending => 'PENDING', model.OrderStatus.confirmed => 'CONFIRMED',
    model.OrderStatus.processing => 'PROCESSING', model.OrderStatus.inTransit => 'IN_TRANSIT',
    model.OrderStatus.deliveredPendingConfirmation => 'DELIVERED_PENDING_CONFIRMATION',
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
