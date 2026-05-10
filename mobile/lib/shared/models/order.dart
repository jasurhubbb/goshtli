// Order — mirrors backend orders.Order. Status enum drives the timeline UI on the order detail screen.
import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';


/// Closed enum mirroring backend Order.Status. Order matters here — it implies the lifecycle progression for UI rendering.
enum OrderStatus {
  @JsonValue('PENDING') pending,
  @JsonValue('CONFIRMED') confirmed,
  @JsonValue('PROCESSING') processing,
  @JsonValue('IN_TRANSIT') inTransit,
  @JsonValue('DELIVERED') delivered,
  @JsonValue('CANCELLED') cancelled,
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
  @JsonKey(name: 'listing') final int listingId;
  @JsonKey(name: 'listing_title') final String listingTitle;
  @JsonKey(name: 'listing_meat_type') final String listingMeatType;
  @JsonKey(name: 'listing_price_per_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double listingPricePerKg;
  @JsonKey(name: 'quantity_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double quantityKg;
  @JsonKey(name: 'total_price', fromJson: _decimalFromString, toJson: _decimalToString) final double totalPrice;
  @JsonKey(name: 'delivery_address') final String deliveryAddress;
  final String notes;
  final OrderStatus status;
  @JsonKey(name: 'created_at') final String createdAt;

  const Order({required this.id, required this.buyerEmail, required this.supplierEmail, required this.supplierUserId,
               required this.listingId, required this.listingTitle, required this.listingMeatType,
               required this.listingPricePerKg, required this.quantityKg, required this.totalPrice,
               required this.deliveryAddress, required this.notes, required this.status, required this.createdAt});

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);

  bool get isTerminal => status == OrderStatus.delivered || status == OrderStatus.cancelled;
}
