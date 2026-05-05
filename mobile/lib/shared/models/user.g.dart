// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: (json['id'] as num).toInt(),
  email: json['email'] as String,
  fullName: json['full_name'] as String,
  phone: json['phone'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  isActive: json['is_active'] as bool,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'full_name': instance.fullName,
  'phone': instance.phone,
  'role': _$UserRoleEnumMap[instance.role]!,
  'is_active': instance.isActive,
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'ADMIN',
  UserRole.supplier: 'SUPPLIER',
  UserRole.buyer: 'BUYER',
};
