// User — mirrors backend's accounts.User. Role enum drives which dashboard the app shows after login.
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';


/// Roles defined on the backend in apps/accounts/models.py — keep these strings byte-identical to the server enum.
enum UserRole {
  @JsonValue('ADMIN') admin,
  @JsonValue('SUPPLIER') supplier,
  @JsonValue('BUYER') buyer,
}


/// v3.3 profile-settings gender enum. Empty string maps to null on the client (unspecified).
enum UserGender {
  @JsonValue('M') male,
  @JsonValue('F') female,
}


@JsonSerializable()
class User {
  final int id;
  final String email;
  @JsonKey(name: 'full_name') final String fullName;
  final String phone;
  final UserRole role;
  @JsonKey(name: 'is_active') final bool isActive;

  // v3.3 profile-settings fields — all nullable since legacy + phone-registered accounts won't have them filled.
  // The server sends empty string for unset CharFields; treat both null and '' as "unset" in the UI.
  @JsonKey(name: 'first_name') final String? firstName;
  @JsonKey(name: 'last_name') final String? lastName;
  final String? patronymic;
  @JsonKey(name: 'date_of_birth') final String? dateOfBirth;  // ISO-8601 YYYY-MM-DD; parsed at the form layer
  @JsonKey(name: 'gender', unknownEnumValue: null) final UserGender? gender;

  // created_at / updated_at omitted — UI never needs them; keeps the model lean
  const User({required this.id, required this.email, required this.fullName,
              required this.phone, required this.role, required this.isActive,
              this.firstName, this.lastName, this.patronymic, this.dateOfBirth, this.gender});

  factory User.fromJson(Map<String, dynamic> json) {
    // DRF sends '' for unset CharField(choices=...) values — normalize to null so the generated enum decoder
    // doesn't throw on the empty string (no enum entry maps to '').
    if (json['gender'] == '') json = {...json, 'gender': null};
    return _$UserFromJson(json);
  }
  Map<String, dynamic> toJson() => _$UserToJson(this);

  // Convenience getters used by routing guards + dashboard switches
  bool get isSupplier => role == UserRole.supplier;
  bool get isBuyer => role == UserRole.buyer;
  bool get isAdmin => role == UserRole.admin;
}
