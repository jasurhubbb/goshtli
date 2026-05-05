// User — mirrors backend's accounts.User. Role enum drives which dashboard the app shows after login.
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';


/// Roles defined on the backend in apps/accounts/models.py — keep these strings byte-identical to the server enum.
enum UserRole {
  @JsonValue('ADMIN') admin,
  @JsonValue('SUPPLIER') supplier,
  @JsonValue('BUYER') buyer,
}


@JsonSerializable()
class User {
  final int id;
  final String email;
  @JsonKey(name: 'full_name') final String fullName;
  final String phone;
  final UserRole role;
  @JsonKey(name: 'is_active') final bool isActive;

  // created_at / updated_at omitted — UI never needs them; keeps the model lean
  const User({required this.id, required this.email, required this.fullName,
              required this.phone, required this.role, required this.isActive});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  // Convenience getters used by routing guards + dashboard switches
  bool get isSupplier => role == UserRole.supplier;
  bool get isBuyer => role == UserRole.buyer;
  bool get isAdmin => role == UserRole.admin;
}
