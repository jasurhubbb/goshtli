// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'buyer_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BuyerProfile _$BuyerProfileFromJson(Map<String, dynamic> json) => BuyerProfile(
  id: (json['id'] as num).toInt(),
  email: json['email'] as String,
  fullName: json['full_name'] as String,
  businessName: json['business_name'] as String,
  region: json['region'] as String,
  address: json['address'] as String,
);

Map<String, dynamic> _$BuyerProfileToJson(BuyerProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'full_name': instance.fullName,
      'business_name': instance.businessName,
      'region': instance.region,
      'address': instance.address,
    };
