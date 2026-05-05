// BuyerProfile — mirrors backend BuyerProfile. No verification field; buyers can act immediately.
import 'package:json_annotation/json_annotation.dart';

part 'buyer_profile.g.dart';


@JsonSerializable()
class BuyerProfile {
  final int id;
  final String email;
  @JsonKey(name: 'full_name') final String fullName;
  @JsonKey(name: 'business_name') final String businessName;
  final String region;
  final String address;

  const BuyerProfile({required this.id, required this.email, required this.fullName,
                      required this.businessName, required this.region, required this.address});

  factory BuyerProfile.fromJson(Map<String, dynamic> json) => _$BuyerProfileFromJson(json);
  Map<String, dynamic> toJson() => _$BuyerProfileToJson(this);
}
