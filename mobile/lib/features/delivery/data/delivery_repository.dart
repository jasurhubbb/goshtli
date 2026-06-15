// DeliveryRepository — single endpoint: POST /delivery/quote/.
//
// The Delivery page hits this on entry (to compute initial pricing) and again every time the buyer
// toggles the butcher option — the available vehicles flip in response, so we re-quote rather than
// running the rules client-side a second time. Cheap (one DB read + math), so this is the right tradeoff.
import '../../../core/network/api_client.dart';
import '../../listings/data/listings_repository.dart' show ApiException;
import 'delivery_models.dart';


class DeliveryRepository {
  final ApiClient _api;
  DeliveryRepository(this._api);

  /// Computes the delivery quote for the current cart + buyer's chosen destination coord. The cart is
  /// passed line-by-line (listing id + qty) so the backend can classify it (raw / live / mixed) and
  /// decide which vehicles are eligible. Pass `butcherServiceRequested: true` to make the backend
  /// switch live-animal carts to Refrigerator (slaughtered meat = cold chain).
  Future<DeliveryQuote> getQuote({
    required List<({int listingId, double quantityKg})> items,
    required double buyerLat,
    required double buyerLng,
    bool butcherServiceRequested = false,
  }) async {
    final r = await _api.dio.post('/delivery/quote/', data: {
      'items': [for (final i in items) {
        'listing': i.listingId,
        'quantity_kg': i.quantityKg.toStringAsFixed(2),
      }],
      'buyer_lat': buyerLat.toStringAsFixed(6),
      'buyer_lng': buyerLng.toStringAsFixed(6),
      'butcher_service_requested': butcherServiceRequested,
    });
    if (r.statusCode == 200) {
      return DeliveryQuote.fromJson(r.data as Map<String, dynamic>);
    }
    throw ApiException('Delivery quote failed (HTTP ${r.statusCode})');
  }
}
