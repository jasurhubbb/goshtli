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

MarketSummary _$MarketSummaryFromJson(Map<String, dynamic> json) =>
    MarketSummary(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      nameUz: json['name_uz'] as String,
      nameRu: json['name_ru'] as String,
      region: json['region'] as String,
      logoUrl: json['logo_url'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$MarketSummaryToJson(MarketSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name_uz': instance.nameUz,
      'name_ru': instance.nameRu,
      'region': instance.region,
      'logo_url': instance.logoUrl,
      'is_active': instance.isActive,
    };

MeatCategorySummary _$MeatCategorySummaryFromJson(Map<String, dynamic> json) =>
    MeatCategorySummary(
      slug: json['slug'] as String,
      nameUz: json['name_uz'] as String,
      nameRu: json['name_ru'] as String,
      imageUrl: json['image_url'] as String? ?? '',
    );

Map<String, dynamic> _$MeatCategorySummaryToJson(
  MeatCategorySummary instance,
) => <String, dynamic>{
  'slug': instance.slug,
  'name_uz': instance.nameUz,
  'name_ru': instance.nameRu,
  'image_url': instance.imageUrl,
};

Listing _$ListingFromJson(Map<String, dynamic> json) => Listing(
  id: (json['id'] as num).toInt(),
  slug: json['slug'] as String,
  market: MarketSummary.fromJson(json['market'] as Map<String, dynamic>),
  category: MeatCategorySummary.fromJson(
    json['category'] as Map<String, dynamic>,
  ),
  nameUz: json['name_uz'] as String,
  nameRu: json['name_ru'] as String,
  descriptionUz: json['description_uz'] as String? ?? '',
  descriptionRu: json['description_ru'] as String? ?? '',
  quantityKg: _decimalFromString(json['quantity_kg']),
  pricePerKg: _decimalFromString(json['price_per_kg']),
  location: json['location'] as String,
  availableFrom: json['available_from'] as String,
  status: $enumDecode(_$ListingStatusEnumMap, json['status']),
  supplierId: (json['supplier_id'] as num?)?.toInt() ?? 0,
  supplierEmail: json['supplier_email'] as String? ?? '',
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => ListingPhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ListingToJson(Listing instance) => <String, dynamic>{
  'id': instance.id,
  'slug': instance.slug,
  'market': instance.market,
  'category': instance.category,
  'name_uz': instance.nameUz,
  'name_ru': instance.nameRu,
  'description_uz': instance.descriptionUz,
  'description_ru': instance.descriptionRu,
  'quantity_kg': _decimalToString(instance.quantityKg),
  'price_per_kg': _decimalToString(instance.pricePerKg),
  'location': instance.location,
  'available_from': instance.availableFrom,
  'status': _$ListingStatusEnumMap[instance.status]!,
  'supplier_id': instance.supplierId,
  'supplier_email': instance.supplierEmail,
  'photos': instance.photos,
};

const _$ListingStatusEnumMap = {
  ListingStatus.active: 'ACTIVE',
  ListingStatus.outOfStock: 'OUT_OF_STOCK',
  ListingStatus.archived: 'ARCHIVED',
};
