// Listing — mirrors backend listings.Listing. quantity_kg / price_per_kg arrive as decimal-formatted strings, parsed to double.
import 'package:json_annotation/json_annotation.dart';

part 'listing.g.dart';


/// Closed enum mirroring backend Listing.MeatType. Drives the meat-type filter chips and badges.
enum MeatType {
  @JsonValue('BEEF') beef,
  @JsonValue('MUTTON') mutton,
  @JsonValue('CHICKEN') chicken,
  @JsonValue('GOAT') goat,
  @JsonValue('HORSE') horse,
  @JsonValue('OTHER') other,
}


/// Closed enum mirroring backend Listing.Status. Drives buyer visibility + supplier badge color.
enum ListingStatus {
  @JsonValue('ACTIVE') active,
  @JsonValue('SOLD_OUT') soldOut,
  @JsonValue('INACTIVE') inactive,
}


/// Convert backend's quoted-decimal strings into double — DRF serializes DecimalField as "100.00", not 100.0.
double _decimalFromString(Object? v) => v == null ? 0 : double.parse(v.toString());
String _decimalToString(double v) => v.toStringAsFixed(2);


@JsonSerializable()
class Listing {
  final int id;
  @JsonKey(name: 'supplier_email') final String supplierEmail;
  @JsonKey(name: 'supplier_business_name') final String supplierBusinessName;
  final String title;
  @JsonKey(name: 'meat_type') final MeatType meatType;
  @JsonKey(name: 'quantity_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double quantityKg;
  @JsonKey(name: 'price_per_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double pricePerKg;
  final String location;
  @JsonKey(name: 'available_from') final String availableFrom;  // ISO date string; UI parses on demand
  final String description;
  final ListingStatus status;

  const Listing({required this.id, required this.supplierEmail, required this.supplierBusinessName,
                 required this.title, required this.meatType, required this.quantityKg,
                 required this.pricePerKg, required this.location, required this.availableFrom,
                 required this.description, required this.status});

  factory Listing.fromJson(Map<String, dynamic> json) => _$ListingFromJson(json);
  Map<String, dynamic> toJson() => _$ListingToJson(this);
}
