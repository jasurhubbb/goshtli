// Listing — mirrors backend listings.Listing. Decimal fields arrive as quoted strings; v2 adds photo gallery + halal/freshness/cold-chain.
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


/// Closed enum mirroring backend Listing.ColdChain. Three meat states drive freshness badges + buyer expectations.
enum ColdChain {
  @JsonValue('FRESH') fresh,
  @JsonValue('CHILLED') chilled,
  @JsonValue('FROZEN') frozen,
}


/// DRF DecimalField serialization helpers — Decimal arrives as "100.00", not 100.0.
double _decimalFromString(Object? v) => v == null ? 0 : double.parse(v.toString());
String _decimalToString(double v) => v.toStringAsFixed(2);


@JsonSerializable()
class ListingPhoto {
  final int id;
  final String url;          // absolute URL the backend built — directly renderable with Image.network()
  final int position;        // gallery order; 0 is the primary thumbnail

  const ListingPhoto({required this.id, required this.url, required this.position});
  factory ListingPhoto.fromJson(Map<String, dynamic> json) => _$ListingPhotoFromJson(json);
  Map<String, dynamic> toJson() => _$ListingPhotoToJson(this);
}


@JsonSerializable()
class Listing {
  final int id;
  @JsonKey(name: 'supplier_id', defaultValue: 0) final int supplierId;
  @JsonKey(name: 'supplier_email') final String supplierEmail;
  @JsonKey(name: 'supplier_business_name') final String supplierBusinessName;
  @JsonKey(name: 'supplier_verified', defaultValue: false) final bool supplierVerified;
  final String title;
  @JsonKey(name: 'meat_type') final MeatType meatType;
  @JsonKey(name: 'quantity_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double quantityKg;
  @JsonKey(name: 'price_per_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double pricePerKg;
  final String location;
  @JsonKey(name: 'available_from') final String availableFrom;
  final String description;
  final ListingStatus status;

  // v2 fields ----------------------------------------------------------------
  @JsonKey(name: 'halal_certified', defaultValue: false) final bool halalCertified;
  @JsonKey(name: 'freshness_date') final String? freshnessDate;            // ISO date or null
  @JsonKey(name: 'cold_chain', defaultValue: ColdChain.fresh) final ColdChain coldChain;
  @JsonKey(name: 'service_area_csv', defaultValue: '') final String serviceAreaCsv;
  @JsonKey(defaultValue: <ListingPhoto>[]) final List<ListingPhoto> photos;

  const Listing({required this.id, required this.supplierId, required this.supplierEmail,
                 required this.supplierBusinessName, required this.supplierVerified,
                 required this.title, required this.meatType, required this.quantityKg,
                 required this.pricePerKg, required this.location, required this.availableFrom,
                 required this.description, required this.status, required this.halalCertified,
                 required this.freshnessDate, required this.coldChain, required this.serviceAreaCsv,
                 required this.photos});

  factory Listing.fromJson(Map<String, dynamic> json) => _$ListingFromJson(json);
  Map<String, dynamic> toJson() => _$ListingToJson(this);

  /// First photo URL or null — used by listing cards for the thumbnail.
  String? get primaryPhotoUrl => photos.isEmpty ? null : photos.first.url;
}
