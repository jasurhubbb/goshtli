// Delivery models — wire shape of POST /api/v1/delivery/quote/.
//
// All Decimal numbers come over as quoted strings (DRF DecimalField round-trips that way), so we parse
// them into doubles on intake. The screen UI passes them around as doubles + formats with formatSoum at
// the render edge.
import 'package:json_annotation/json_annotation.dart';

part 'delivery_models.g.dart';


/// Mirrors backend Order.VehicleType — used by the radio selector. Wire values match the backend
/// canonical strings so the chosen option can be posted straight back into Order.delivery_vehicle_type.
enum VehicleType {
  @JsonValue('REFRIGERATOR') refrigerator,
  @JsonValue('CHORVA_TAXI') chorvaTaxi,
}


/// Mirrors backend Order.TimeSlot. The label text comes from L10n on the client; this enum is just for
/// the round-trip on the wire.
enum DeliveryTimeSlot {
  @JsonValue('SLOT_0609') slot0609,
  @JsonValue('SLOT_0913') slot0913,
  @JsonValue('SLOT_1318') slot1318,
}


double _decimalFromString(Object? v) => v == null ? 0 : double.parse(v.toString());


@JsonSerializable()
class VehicleOption {
  /// Backend enum value as a string (e.g. "REFRIGERATOR"). We parse it lazily — kept as string so the
  /// server can add new vehicle types without forcing a mobile release.
  final String code;
  final bool available;
  @JsonKey(name: 'reason_unavailable', defaultValue: '') final String reasonUnavailable;
  @JsonKey(name: 'base_fee', fromJson: _decimalFromString) final double baseFee;
  @JsonKey(name: 'per_km_fee', fromJson: _decimalFromString) final double perKmFee;
  @JsonKey(name: 'distance_km', fromJson: _decimalFromString) final double distanceKm;
  @JsonKey(name: 'total_price', fromJson: _decimalFromString) final double totalPrice;

  const VehicleOption({required this.code, required this.available,
                       required this.reasonUnavailable, required this.baseFee, required this.perKmFee,
                       required this.distanceKm, required this.totalPrice});

  factory VehicleOption.fromJson(Map<String, dynamic> json) => _$VehicleOptionFromJson(json);
  Map<String, dynamic> toJson() => _$VehicleOptionToJson(this);

  /// True when this row corresponds to the cold-chain refrigerator vehicle.
  bool get isRefrigerator => code == 'REFRIGERATOR';

  /// True when this row corresponds to the open-bed live-animal vehicle.
  bool get isChorvaTaxi => code == 'CHORVA_TAXI';
}


@JsonSerializable()
class TimeSlotOption {
  final String code;             // wire value matching DeliveryTimeSlot
  final String label;            // human label — backend ships the canonical "06:00 – 09:00" string
  const TimeSlotOption({required this.code, required this.label});
  factory TimeSlotOption.fromJson(Map<String, dynamic> json) => _$TimeSlotOptionFromJson(json);
  Map<String, dynamic> toJson() => _$TimeSlotOptionToJson(this);
}


@JsonSerializable()
class ButcherServiceQuote {
  /// True when cart has at least one live-animal line — only then is the butcher option offered.
  final bool available;
  /// True when the buyer ticked "yes, I want the butcher to slaughter+cut" (passed in via the quote request).
  final bool requested;
  /// The fee that will actually be charged on this order (0 if not requested).
  @JsonKey(fromJson: _decimalFromString) final double fee;
  /// The rate-card amount — always shown so the buyer sees how much the upsell would cost before opting in.
  @JsonKey(name: 'flat_fee', fromJson: _decimalFromString) final double flatFee;

  const ButcherServiceQuote({required this.available, required this.requested,
                             required this.fee, required this.flatFee});
  factory ButcherServiceQuote.fromJson(Map<String, dynamic> json) => _$ButcherServiceQuoteFromJson(json);
  Map<String, dynamic> toJson() => _$ButcherServiceQuoteToJson(this);
}


@JsonSerializable()
class DeliveryQuote {
  @JsonKey(name: 'distance_km', fromJson: _decimalFromString) final double distanceKm;
  final List<VehicleOption> options;
  @JsonKey(name: 'time_slots') final List<TimeSlotOption> timeSlots;
  @JsonKey(name: 'butcher_service') final ButcherServiceQuote butcherService;
  @JsonKey(name: 'cart_has_live_animal') final bool cartHasLiveAnimal;

  const DeliveryQuote({required this.distanceKm, required this.options, required this.timeSlots,
                       required this.butcherService, required this.cartHasLiveAnimal});

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) => _$DeliveryQuoteFromJson(json);
  Map<String, dynamic> toJson() => _$DeliveryQuoteToJson(this);
}
