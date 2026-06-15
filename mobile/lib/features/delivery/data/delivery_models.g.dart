// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VehicleOption _$VehicleOptionFromJson(Map<String, dynamic> json) =>
    VehicleOption(
      code: json['code'] as String,
      available: json['available'] as bool,
      reasonUnavailable: json['reason_unavailable'] as String? ?? '',
      baseFee: _decimalFromString(json['base_fee']),
      perKmFee: _decimalFromString(json['per_km_fee']),
      distanceKm: _decimalFromString(json['distance_km']),
      totalPrice: _decimalFromString(json['total_price']),
    );

Map<String, dynamic> _$VehicleOptionToJson(VehicleOption instance) =>
    <String, dynamic>{
      'code': instance.code,
      'available': instance.available,
      'reason_unavailable': instance.reasonUnavailable,
      'base_fee': instance.baseFee,
      'per_km_fee': instance.perKmFee,
      'distance_km': instance.distanceKm,
      'total_price': instance.totalPrice,
    };

TimeSlotOption _$TimeSlotOptionFromJson(Map<String, dynamic> json) =>
    TimeSlotOption(
      code: json['code'] as String,
      label: json['label'] as String,
    );

Map<String, dynamic> _$TimeSlotOptionToJson(TimeSlotOption instance) =>
    <String, dynamic>{'code': instance.code, 'label': instance.label};

ButcherServiceQuote _$ButcherServiceQuoteFromJson(Map<String, dynamic> json) =>
    ButcherServiceQuote(
      available: json['available'] as bool,
      requested: json['requested'] as bool,
      fee: _decimalFromString(json['fee']),
      flatFee: _decimalFromString(json['flat_fee']),
    );

Map<String, dynamic> _$ButcherServiceQuoteToJson(
  ButcherServiceQuote instance,
) => <String, dynamic>{
  'available': instance.available,
  'requested': instance.requested,
  'fee': instance.fee,
  'flat_fee': instance.flatFee,
};

DeliveryQuote _$DeliveryQuoteFromJson(Map<String, dynamic> json) =>
    DeliveryQuote(
      distanceKm: _decimalFromString(json['distance_km']),
      options: (json['options'] as List<dynamic>)
          .map((e) => VehicleOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeSlots: (json['time_slots'] as List<dynamic>)
          .map((e) => TimeSlotOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      butcherService: ButcherServiceQuote.fromJson(
        json['butcher_service'] as Map<String, dynamic>,
      ),
      cartHasLiveAnimal: json['cart_has_live_animal'] as bool,
    );

Map<String, dynamic> _$DeliveryQuoteToJson(DeliveryQuote instance) =>
    <String, dynamic>{
      'distance_km': instance.distanceKm,
      'options': instance.options,
      'time_slots': instance.timeSlots,
      'butcher_service': instance.butcherService,
      'cart_has_live_animal': instance.cartHasLiveAnimal,
    };
