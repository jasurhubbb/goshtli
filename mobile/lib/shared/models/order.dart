// Order — mirrors backend orders.Order. Status enum drives the timeline UI on the order detail screen.
import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';


/// Closed enum mirroring backend Order.Status. Order matters here — it implies the lifecycle progression for UI rendering.
enum OrderStatus {
  @JsonValue('PENDING') pending,
  @JsonValue('CONFIRMED') confirmed,
  @JsonValue('PROCESSING') processing,
  @JsonValue('IN_TRANSIT') inTransit,
  // v3.9.14 — courier marked "delivered" from their side; waits for the buyer to tap "Buyurtmani
  // qabul qildim" in this app to finalize. Prevents "did it actually arrive?" disputes.
  @JsonValue('DELIVERED_PENDING_CONFIRMATION') deliveredPendingConfirmation,
  @JsonValue('DELIVERED') delivered,
  @JsonValue('CANCELLED') cancelled,
}


/// v3.5 — mirrors backend Order.PaymentStatus. Separate axis from fulfilment `status`: an order can be
/// CONFIRMED (supplier accepted) AND payment FAILED (insufficient funds) at the same time.
enum OrderPaymentStatus {
  @JsonValue('UNPAID') unpaid,
  @JsonValue('PENDING') pending,
  @JsonValue('PAID') paid,
  @JsonValue('FAILED') failed,
  @JsonValue('REFUNDED') refunded,
}


/// Same decimal helpers as Listing — DRF DecimalField round-trips as quoted strings.
double _decimalFromString(Object? v) => v == null ? 0 : double.parse(v.toString());
String _decimalToString(double v) => v.toStringAsFixed(2);


@JsonSerializable()
class Order {
  final int id;
  @JsonKey(name: 'buyer_email') final String buyerEmail;
  @JsonKey(name: 'supplier_email') final String supplierEmail;
  @JsonKey(name: 'supplier_user_id', defaultValue: 0) final int supplierUserId;
  // v3.7 display-friendly identity fields. Kimdan = market name; Kimga = buyer full name + phone.
  @JsonKey(name: 'buyer_name', defaultValue: '') final String buyerName;
  @JsonKey(name: 'buyer_phone', defaultValue: '') final String buyerPhone;
  @JsonKey(name: 'seller_name_uz', defaultValue: '') final String sellerNameUz;
  @JsonKey(name: 'seller_name_ru', defaultValue: '') final String sellerNameRu;
  @JsonKey(name: 'listing') final int listingId;
  // v3.1 schema — bilingual name + category slug replace the old listing_title + listing_meat_type pair.
  // We keep `listingTitle` as a getter (see below) so call sites in orders_screen / order_detail render
  // a localized name without each one re-implementing the picker.
  @JsonKey(name: 'listing_name_uz', defaultValue: '') final String listingNameUz;
  @JsonKey(name: 'listing_name_ru', defaultValue: '') final String listingNameRu;
  @JsonKey(name: 'listing_category_slug', defaultValue: '') final String listingCategorySlug;
  @JsonKey(name: 'listing_market_slug', defaultValue: '') final String listingMarketSlug;
  @JsonKey(name: 'listing_price_per_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double listingPricePerKg;
  @JsonKey(name: 'quantity_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double quantityKg;
  @JsonKey(name: 'total_price', fromJson: _decimalFromString, toJson: _decimalToString) final double totalPrice;
  @JsonKey(name: 'delivery_address') final String deliveryAddress;
  final String notes;
  final OrderStatus status;
  // v3.5 payment fields. Default to unpaid + empty url so older API responses (before the migration)
  // deserialize cleanly during the rollout window.
  @JsonKey(name: 'payment_status', defaultValue: OrderPaymentStatus.unpaid) final OrderPaymentStatus paymentStatus;
  @JsonKey(name: 'payment_url', defaultValue: '') final String paymentUrl;
  @JsonKey(name: 'created_at') final String createdAt;

  const Order({required this.id, required this.buyerEmail, required this.supplierEmail, required this.supplierUserId,
               this.buyerName = '', this.buyerPhone = '',
               this.sellerNameUz = '', this.sellerNameRu = '',
               required this.listingId, this.listingNameUz = '', this.listingNameRu = '',
               this.listingCategorySlug = '', this.listingMarketSlug = '',
               required this.listingPricePerKg, required this.quantityKg, required this.totalPrice,
               required this.deliveryAddress, required this.notes, required this.status,
               this.paymentStatus = OrderPaymentStatus.unpaid, this.paymentUrl = '',
               required this.createdAt});

  /// Buyer-facing seller name. Defaults to the Uzbek market name; falls back to Russian, then to the
  /// supplier email when no market was attached (legacy rows). Use this on the order detail "Kimdan" row.
  String sellerDisplayName(String langCode) {
    if (langCode == 'ru' && sellerNameRu.isNotEmpty) return sellerNameRu;
    if (sellerNameUz.isNotEmpty) return sellerNameUz;
    if (sellerNameRu.isNotEmpty) return sellerNameRu;
    return supplierEmail;
  }

  /// Buyer-facing buyer name + phone. "Jasur M · +998 99 128 37 05" or just the phone when full_name
  /// is empty. Used on the order detail "Kimga" row — never shows the synthetic phone-email anymore.
  String buyerDisplay() {
    final phone = buyerPhone.isNotEmpty ? buyerPhone : '';
    if (buyerName.isNotEmpty && phone.isNotEmpty) return '$buyerName · $phone';
    if (buyerName.isNotEmpty) return buyerName;
    if (phone.isNotEmpty) return phone;
    return buyerEmail;
  }

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);

  bool get isTerminal => status == OrderStatus.delivered || status == OrderStatus.cancelled;

  // Language-aware fallback so older call sites still render a name. Uz takes priority when both exist
  // (most of the catalog is uz-first); Ru is the fallback for users on the ru locale.
  String displayName(String langCode) {
    if (langCode == 'ru' && listingNameRu.isNotEmpty) return listingNameRu;
    return listingNameUz.isNotEmpty ? listingNameUz : listingNameRu;
  }

  // Back-compat for screens written against the v3.0 schema — picks uz by default. Call sites that have
  // a BuildContext should prefer `displayName(Localizations.localeOf(context).languageCode)` instead.
  String get listingTitle => listingNameUz.isNotEmpty ? listingNameUz : listingNameRu;
}
