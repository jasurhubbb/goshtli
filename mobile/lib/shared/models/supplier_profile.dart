// SupplierProfile — mirrors backend SupplierProfile. is_verified gates listing creation in the UI.
import 'package:json_annotation/json_annotation.dart';

part 'supplier_profile.g.dart';


@JsonSerializable()
class SupplierProfile {
  final int id;
  final String email;
  @JsonKey(name: 'full_name') final String fullName;
  @JsonKey(name: 'business_name') final String businessName;
  final String region;
  final String address;
  @JsonKey(name: 'is_verified') final bool isVerified;

  const SupplierProfile({required this.id, required this.email, required this.fullName,
                         required this.businessName, required this.region,
                         required this.address, required this.isVerified});

  factory SupplierProfile.fromJson(Map<String, dynamic> json) => _$SupplierProfileFromJson(json);
  Map<String, dynamic> toJson() => _$SupplierProfileToJson(this);
}
