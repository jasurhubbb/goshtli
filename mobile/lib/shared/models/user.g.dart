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
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  patronymic: json['patronymic'] as String?,
  dateOfBirth: json['date_of_birth'] as String?,
  gender: $enumDecodeNullable(_$UserGenderEnumMap, json['gender']),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'full_name': instance.fullName,
  'phone': instance.phone,
  'role': _$UserRoleEnumMap[instance.role]!,
  'is_active': instance.isActive,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'patronymic': instance.patronymic,
  'date_of_birth': instance.dateOfBirth,
  'gender': _$UserGenderEnumMap[instance.gender],
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'ADMIN',
  UserRole.supplier: 'SUPPLIER',
  UserRole.buyer: 'BUYER',
};

const _$UserGenderEnumMap = {UserGender.male: 'M', UserGender.female: 'F'};
