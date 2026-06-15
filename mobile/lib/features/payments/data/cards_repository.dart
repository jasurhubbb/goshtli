// CardsRepository — all /payments/cards/* + /payments/orders/<id>/pay-with-card/ calls.
//
// Auth: every endpoint here requires a bearer (IsAuthenticated). The repository itself doesn't gate —
// the UI's PaymentMethodPicker checks auth state and routes to login first when anonymous.
import '../../../core/network/api_client.dart';
import '../../listings/data/listings_repository.dart' show ApiException;
import 'card_model.dart';


class CardsRepository {
  final ApiClient _api;
  CardsRepository(this._api);

  /// GET /payments/cards/ — buyer's saved cards. Default first, then newest. Backend filters by user.
  Future<List<PaymentCard>> list() async {
    final r = await _api.dio.get('/payments/cards/');
    if (r.statusCode == 200) {
      final raw = r.data as List;
      return raw.map((e) => PaymentCard.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('Cards list failed (HTTP ${r.statusCode})');
  }

  /// POST /payments/cards/ — add a new card. PAN + CVC are passed to the backend ONCE and never stored
  /// client-side after the call returns. We strip spaces from the PAN here so the backend sees clean digits.
  Future<PaymentCard> add({
    required String pan,
    required int expiresMonth,
    required int expiresYear,
    required String cvc,
    String holderName = '',
    String phoneForSms = '',
    bool makeDefault = false,
  }) async {
    final r = await _api.dio.post('/payments/cards/', data: {
      'pan': pan.replaceAll(RegExp(r'\s+'), ''),
      'expires_mm': expiresMonth,
      // Backend accepts both 2- and 4-digit; we send raw to preserve user intent (2025 vs 25).
      'expires_yy': expiresYear,
      'cvc': cvc,
      'holder_name': holderName,
      'phone_for_sms': phoneForSms,
      'make_default': makeDefault,
    });
    if (r.statusCode == 201) return PaymentCard.fromJson(r.data as Map<String, dynamic>);
    throw _toApiException(r);
  }

  /// DELETE /payments/cards/<id>/ — remove. 204 on success. Only the owner can delete.
  Future<void> delete(int id) async {
    final r = await _api.dio.delete('/payments/cards/$id/');
    if (r.statusCode != 204) throw _toApiException(r);
  }

  /// POST /payments/cards/<id>/set-default/ — atomic promote. Returns the refreshed list so the picker
  /// can show the new default without a separate GET.
  Future<List<PaymentCard>> setDefault(int id) async {
    final r = await _api.dio.post('/payments/cards/$id/set-default/');
    if (r.statusCode == 200) {
      final raw = r.data as List;
      return raw.map((e) => PaymentCard.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _toApiException(r);
  }

  /// POST /payments/orders/<order_id>/pay-with-card/ — settle the order with the chosen card.
  /// Mock mode: instant success. Real Payme mode (future): may return 202 + an SMS challenge.
  Future<({String paymentStatus, String cardLast4, String cardBrand})> payWithCard({
    required int orderId,
    required int cardId,
    String smsCode = '',
  }) async {
    final r = await _api.dio.post('/payments/orders/$orderId/pay-with-card/',
        data: {'card_id': cardId, 'sms_code': smsCode});
    if (r.statusCode == 200) {
      final d = r.data as Map<String, dynamic>;
      return (
        paymentStatus: d['payment_status'] as String,
        cardLast4: d['card_last_4'] as String,
        cardBrand: d['card_brand'] as String,
      );
    }
    throw _toApiException(r);
  }

  ApiException _toApiException(dynamic r) {
    if (r.data is Map<String, dynamic>) {
      final m = r.data as Map<String, dynamic>;
      if (m['detail'] is String) return ApiException(m['detail'] as String);
      final field = <String, List<String>>{};
      m.forEach((k, v) { if (v is List) field[k] = v.map((e) => e.toString()).toList(); });
      if (field.isNotEmpty) {
        return ApiException(field.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n'), field);
      }
    }
    return ApiException('Card request failed (HTTP ${r.statusCode})');
  }
}
