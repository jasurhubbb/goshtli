// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Listing _$ListingFromJson(Map<String, dynamic> json) => Listing(
  id: (json['id'] as num).toInt(),
  supplierEmail: json['supplier_email'] as String,
  supplierBusinessName: json['supplier_business_name'] as String,
  title: json['title'] as String,
  meatType: $enumDecode(_$MeatTypeEnumMap, json['meat_type']),
  quantityKg: _decimalFromString(json['quantity_kg']),
  pricePerKg: _decimalFromString(json['price_per_kg']),
  location: json['location'] as String,
  availableFrom: json['available_from'] as String,
  description: json['description'] as String,
  status: $enumDecode(_$ListingStatusEnumMap, json['status']),
);

Map<String, dynamic> _$ListingToJson(Listing instance) => <String, dynamic>{
  'id': instance.id,
  'supplier_email': instance.supplierEmail,
  'supplier_business_name': instance.supplierBusinessName,
  'title': instance.title,
  'meat_type': _$MeatTypeEnumMap[instance.meatType]!,
  'quantity_kg': _decimalToString(instance.quantityKg),
  'price_per_kg': _decimalToString(instance.pricePerKg),
  'location': instance.location,
  'available_from': instance.availableFrom,
  'description': instance.description,
  'status': _$ListingStatusEnumMap[instance.status]!,
};

const _$MeatTypeEnumMap = {
  MeatType.beef: 'BEEF',
  MeatType.mutton: 'MUTTON',
  MeatType.chicken: 'CHICKEN',
  MeatType.goat: 'GOAT',
  MeatType.horse: 'HORSE',
  MeatType.other: 'OTHER',
};

const _$ListingStatusEnumMap = {
  ListingStatus.active: 'ACTIVE',
  ListingStatus.soldOut: 'SOLD_OUT',
  ListingStatus.inactive: 'INACTIVE',
};
