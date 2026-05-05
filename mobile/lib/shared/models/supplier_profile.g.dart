// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SupplierProfile _$SupplierProfileFromJson(Map<String, dynamic> json) =>
    SupplierProfile(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      businessName: json['business_name'] as String,
      region: json['region'] as String,
      address: json['address'] as String,
      isVerified: json['is_verified'] as bool,
    );

Map<String, dynamic> _$SupplierProfileToJson(SupplierProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'full_name': instance.fullName,
      'business_name': instance.businessName,
      'region': instance.region,
      'address': instance.address,
      'is_verified': instance.isVerified,
    };
