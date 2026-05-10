// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListingPhoto _$ListingPhotoFromJson(Map<String, dynamic> json) => ListingPhoto(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  position: (json['position'] as num).toInt(),
);

Map<String, dynamic> _$ListingPhotoToJson(ListingPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'position': instance.position,
    };

Listing _$ListingFromJson(Map<String, dynamic> json) => Listing(
  id: (json['id'] as num).toInt(),
  supplierEmail: json['supplier_email'] as String,
  supplierBusinessName: json['supplier_business_name'] as String,
  supplierVerified: json['supplier_verified'] as bool? ?? false,
  title: json['title'] as String,
  meatType: $enumDecode(_$MeatTypeEnumMap, json['meat_type']),
  quantityKg: _decimalFromString(json['quantity_kg']),
  pricePerKg: _decimalFromString(json['price_per_kg']),
  location: json['location'] as String,
  availableFrom: json['available_from'] as String,
  description: json['description'] as String,
  status: $enumDecode(_$ListingStatusEnumMap, json['status']),
  halalCertified: json['halal_certified'] as bool? ?? false,
  freshnessDate: json['freshness_date'] as String?,
  coldChain:
      $enumDecodeNullable(_$ColdChainEnumMap, json['cold_chain']) ??
      ColdChain.fresh,
  serviceAreaCsv: json['service_area_csv'] as String? ?? '',
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => ListingPhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ListingToJson(Listing instance) => <String, dynamic>{
  'id': instance.id,
  'supplier_email': instance.supplierEmail,
  'supplier_business_name': instance.supplierBusinessName,
  'supplier_verified': instance.supplierVerified,
  'title': instance.title,
  'meat_type': _$MeatTypeEnumMap[instance.meatType]!,
  'quantity_kg': _decimalToString(instance.quantityKg),
  'price_per_kg': _decimalToString(instance.pricePerKg),
  'location': instance.location,
  'available_from': instance.availableFrom,
  'description': instance.description,
  'status': _$ListingStatusEnumMap[instance.status]!,
  'halal_certified': instance.halalCertified,
  'freshness_date': instance.freshnessDate,
  'cold_chain': _$ColdChainEnumMap[instance.coldChain]!,
  'service_area_csv': instance.serviceAreaCsv,
  'photos': instance.photos,
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

const _$ColdChainEnumMap = {
  ColdChain.fresh: 'FRESH',
  ColdChain.chilled: 'CHILLED',
  ColdChain.frozen: 'FROZEN',
};
