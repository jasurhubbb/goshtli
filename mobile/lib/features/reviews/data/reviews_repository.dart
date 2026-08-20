// ReviewsRepository — lets a buyer review a completed order.
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../listings/data/listings_repository.dart' show ApiException;

class ReviewsRepository {
  final ApiClient _api;
  ReviewsRepository(this._api);

  /// Post a new review. Backend enforces: caller is the buyer, order is DELIVERED, no existing review.
  Future<void> create({
    required int orderId,
    required int rating,
    String comment = '',
  }) async {
    final r = await _api.dio.post(
      '/reviews/',
      data: {'order': orderId, 'rating': rating, 'comment': comment},
    );
    if (r.statusCode == 201) return;
    throw _err(r);
  }

  ApiException _err(Response r) {
    if (r.data is Map<String, dynamic>) {
      final m = r.data as Map<String, dynamic>;
      if (m['detail'] is String) return ApiException(m['detail'] as String);
      // DRF returns {field: [msg]} for 400 — join all messages so the user sees something useful
      final field = <String, List<String>>{};
      m.forEach((k, v) {
        if (v is List) field[k] = v.map((e) => e.toString()).toList();
      });
      return ApiException(
        field.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n'),
        field,
      );
    }
    return ApiException('HTTP ${r.statusCode}');
  }
}
