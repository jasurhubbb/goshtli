// ReviewsRepository — list + create reviews + supplier rating aggregate.
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/paginated.dart';
import '../../listings/data/listings_repository.dart' show ApiException;


/// One review row. Shown on supplier detail + on the order detail (after delivery).
class Review {
  final int id;
  final int orderId;
  final String buyerEmail;
  final String supplierEmail;
  final int rating;             // 1-5
  final String comment;
  final String createdAt;

  const Review({required this.id, required this.orderId, required this.buyerEmail, required this.supplierEmail,
                required this.rating, required this.comment, required this.createdAt});

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as int,
        orderId: j['order_id'] as int,
        buyerEmail: (j['buyer_email'] ?? '') as String,
        supplierEmail: (j['supplier_email'] ?? '') as String,
        rating: j['rating'] as int,
        comment: (j['comment'] ?? '') as String,
        createdAt: (j['created_at'] ?? '') as String);
}


/// Aggregate (avg + count) for a supplier — what we put next to "23 reviews · 4.6★".
class SupplierRating {
  final double avg;
  final int count;
  const SupplierRating({required this.avg, required this.count});
  factory SupplierRating.fromJson(Map<String, dynamic> j) => SupplierRating(
        avg: (j['avg_rating'] ?? 0).toDouble(), count: (j['count'] ?? 0) as int);
}


class ReviewsRepository {
  final ApiClient _api;
  ReviewsRepository(this._api);

  Future<Paginated<Review>> listForSupplier(int supplierId) async {
    final r = await _api.dio.get('/reviews/', queryParameters: {'supplier': supplierId});
    if (r.statusCode == 200) return Paginated.fromJson(r.data as Map<String, dynamic>, Review.fromJson);
    throw _err(r);
  }

  Future<SupplierRating> aggregateForSupplier(int supplierId) async {
    final r = await _api.dio.get('/reviews/supplier/$supplierId/aggregate/');
    if (r.statusCode == 200) return SupplierRating.fromJson(r.data as Map<String, dynamic>);
    throw _err(r);
  }

  /// Post a new review. Backend enforces: caller is the buyer, order is DELIVERED, no existing review.
  Future<Review> create({required int orderId, required int rating, String comment = ''}) async {
    final r = await _api.dio.post('/reviews/', data: {'order': orderId, 'rating': rating, 'comment': comment});
    if (r.statusCode == 201) return Review.fromJson(r.data as Map<String, dynamic>);
    throw _err(r);
  }

  ApiException _err(Response r) {
    if (r.data is Map<String, dynamic>) {
      final m = r.data as Map<String, dynamic>;
      if (m['detail'] is String) return ApiException(m['detail'] as String);
      // DRF returns {field: [msg]} for 400 — join all messages so the user sees something useful
      final field = <String, List<String>>{};
      m.forEach((k, v) { if (v is List) field[k] = v.map((e) => e.toString()).toList(); });
      return ApiException(field.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n'), field);
    }
    return ApiException('HTTP ${r.statusCode}');
  }
}
