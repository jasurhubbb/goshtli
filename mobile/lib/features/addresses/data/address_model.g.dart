// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Address _$AddressFromJson(Map<String, dynamic> json) => Address(
  id: (json['id'] as num).toInt(),
  label: json['label'] as String,
  address: json['address'] as String,
  entrance: json['entrance'] as String? ?? '',
  floor: json['floor'] as String? ?? '',
  apartment: json['apartment'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
  lat: _decimalFromString(json['lat']),
  lng: _decimalFromString(json['lng']),
  isDefault: json['is_default'] as bool? ?? false,
);

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'address': instance.address,
  'entrance': instance.entrance,
  'floor': instance.floor,
  'apartment': instance.apartment,
  'notes': instance.notes,
  'lat': _decimalToString(instance.lat),
  'lng': _decimalToString(instance.lng),
  'is_default': instance.isDefault,
};
