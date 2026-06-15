// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentCard _$PaymentCardFromJson(Map<String, dynamic> json) => PaymentCard(
  id: (json['id'] as num).toInt(),
  last4: json['last_4'] as String,
  brand: $enumDecode(_$CardBrandEnumMap, json['brand']),
  expiresMonth: (json['expires_month'] as num).toInt(),
  expiresYear: (json['expires_year'] as num).toInt(),
  holderName: json['holder_name'] as String? ?? '',
  phoneForSms: json['phone_for_sms'] as String? ?? '',
  isDefault: json['is_default'] as bool? ?? false,
  createdAt: json['created_at'] as String? ?? '',
);

Map<String, dynamic> _$PaymentCardToJson(PaymentCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'last_4': instance.last4,
      'brand': _$CardBrandEnumMap[instance.brand]!,
      'expires_month': instance.expiresMonth,
      'expires_year': instance.expiresYear,
      'holder_name': instance.holderName,
      'phone_for_sms': instance.phoneForSms,
      'is_default': instance.isDefault,
      'created_at': instance.createdAt,
    };

const _$CardBrandEnumMap = {
  CardBrand.humo: 'HUMO',
  CardBrand.uzcard: 'UZCARD',
  CardBrand.visa: 'VISA',
  CardBrand.mastercard: 'MASTERCARD',
  CardBrand.unknown: 'UNKNOWN',
};
