// Listing — mirrors backend apps/listings/Listing after the v3.1 catalog overhaul.
//
// Schema in line with the new Django model:
//   • Belongs to ONE Market (vendor) — nested MarketSummary expanded inline
//   • Has ONE MeatCategory (facet) — nested MeatCategorySummary expanded inline
//   • Bilingual name + description (uz / ru). Display layer picks based on Localizations.localeOf().
//   • Status: ACTIVE / OUT_OF_STOCK / ARCHIVED (no DRAFT / PAUSED — see apps/listings/models.py)
//   • Photos: list of ListingPhoto rows; first one is the primary thumbnail
//
// DEPRECATED & REMOVED: title, meatType, halalCertified, freshnessDate, coldChain, serviceAreaCsv.
import 'package:json_annotation/json_annotation.dart';

part 'listing.g.dart';


/// Closed enum mirroring backend Listing.Status. Drives buyer visibility + admin badge colour.
enum ListingStatus {
  @JsonValue('ACTIVE') active,
  @JsonValue('OUT_OF_STOCK') outOfStock,
  @JsonValue('ARCHIVED') archived,
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


/// Nested Market embed returned inside Listing.market. Compact: only the fields a product card needs to render
/// the "from <Market> in <region>" line — full market detail comes from the dedicated /markets/<slug>/ endpoint.
@JsonSerializable()
class MarketSummary {
  final int id;
  final String slug;
  @JsonKey(name: 'name_uz') final String nameUz;
  @JsonKey(name: 'name_ru') final String nameRu;
  final String region;
  @JsonKey(name: 'logo_url', defaultValue: '') final String logoUrl;
  @JsonKey(name: 'is_active', defaultValue: true) final bool isActive;

  const MarketSummary({required this.id, required this.slug, required this.nameUz, required this.nameRu,
                       required this.region, required this.logoUrl, required this.isActive});

  factory MarketSummary.fromJson(Map<String, dynamic> json) => _$MarketSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MarketSummaryToJson(this);

  /// Display name for the active locale code. Falls back to Uzbek for any non-RU language.
  String displayName(String languageCode) => languageCode == 'ru' ? nameRu : nameUz;
}


/// Nested MeatCategory embed returned inside Listing.category. Same compact shape as MarketSummary.
@JsonSerializable()
class MeatCategorySummary {
  final String slug;
  @JsonKey(name: 'name_uz') final String nameUz;
  @JsonKey(name: 'name_ru') final String nameRu;
  @JsonKey(name: 'image_url', defaultValue: '') final String imageUrl;

  const MeatCategorySummary({required this.slug, required this.nameUz, required this.nameRu,
                             required this.imageUrl});

  factory MeatCategorySummary.fromJson(Map<String, dynamic> json) => _$MeatCategorySummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MeatCategorySummaryToJson(this);

  String displayName(String languageCode) => languageCode == 'ru' ? nameRu : nameUz;
}


@JsonSerializable()
class Listing {
  final int id;
  final String slug;

  // Nested embeds — present in responses; on writes the caller sends market_id / category_id instead.
  final MarketSummary market;
  final MeatCategorySummary category;

  // Bilingual content
  @JsonKey(name: 'name_uz') final String nameUz;
  @JsonKey(name: 'name_ru') final String nameRu;
  @JsonKey(name: 'description_uz', defaultValue: '') final String descriptionUz;
  @JsonKey(name: 'description_ru', defaultValue: '') final String descriptionRu;

  // Commerce
  @JsonKey(name: 'quantity_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double quantityKg;
  @JsonKey(name: 'price_per_kg', fromJson: _decimalFromString, toJson: _decimalToString) final double pricePerKg;
  final String location;
  @JsonKey(name: 'available_from') final String availableFrom;
  final ListingStatus status;

  // Legacy supplier embeds — still on the response for chat / order code paths to identify the seller
  @JsonKey(name: 'supplier_id', defaultValue: 0) final int supplierId;
  @JsonKey(name: 'supplier_email', defaultValue: '') final String supplierEmail;

  @JsonKey(defaultValue: <ListingPhoto>[]) final List<ListingPhoto> photos;

  const Listing({required this.id, required this.slug, required this.market, required this.category,
                 required this.nameUz, required this.nameRu, required this.descriptionUz, required this.descriptionRu,
                 required this.quantityKg, required this.pricePerKg, required this.location,
                 required this.availableFrom, required this.status,
                 required this.supplierId, required this.supplierEmail, required this.photos});

  factory Listing.fromJson(Map<String, dynamic> json) => _$ListingFromJson(json);
  Map<String, dynamic> toJson() => _$ListingToJson(this);

  /// First photo URL or null — used by listing cards for the thumbnail. Returns null when there are no photos
  /// (UI falls back to a category icon or placeholder).
  String? get primaryPhotoUrl => photos.isEmpty ? null : photos.first.url;

  /// Display name for the active locale. Falls back to Uzbek for any non-RU language.
  String displayName(String languageCode) =>
      languageCode == 'ru' && nameRu.isNotEmpty ? nameRu : nameUz;
}
