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


/// v3.6 PRD §2 — sold per kilo (raw meat OR live by weight) vs. per head (live by head). The buyer-side
/// quantity stepper math differs by this: BY_HEAD increments by 1 (one animal), BY_WEIGHT increments by 5/10kg.
enum ListingSaleType {
  @JsonValue('BY_WEIGHT') byWeight,
  @JsonValue('BY_HEAD') byHead,
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

  // ---- v3.6 PRD §2 live-animal fields ----
  // is_live_animal: when true, the buyer card swaps the meat slab thumbnail for the live animal photo
  // and shows a "Tirik vazn" or "1 Bosh" badge. Cart adds a butcher service prompt when any item has
  // this flag set.
  @JsonKey(name: 'is_live_animal', defaultValue: false) final bool isLiveAnimal;
  @JsonKey(name: 'sale_type', defaultValue: ListingSaleType.byWeight) final ListingSaleType saleType;
  @JsonKey(name: 'estimated_meat_yield_pct', defaultValue: 0) final int estimatedMeatYieldPct;
  @JsonKey(name: 'breed_type', defaultValue: '') final String breedType;
  @JsonKey(name: 'head_count', defaultValue: 0) final int headCount;
  @JsonKey(name: 'live_weight_per_head_kg', fromJson: _decimalFromString, toJson: _decimalToString,
           defaultValue: 0.0) final double liveWeightPerHeadKg;

  @JsonKey(defaultValue: <ListingPhoto>[]) final List<ListingPhoto> photos;

  const Listing({required this.id, required this.slug, required this.market, required this.category,
                 required this.nameUz, required this.nameRu, required this.descriptionUz, required this.descriptionRu,
                 required this.quantityKg, required this.pricePerKg, required this.location,
                 required this.availableFrom, required this.status,
                 required this.supplierId, required this.supplierEmail,
                 this.isLiveAnimal = false, this.saleType = ListingSaleType.byWeight,
                 this.estimatedMeatYieldPct = 0, this.breedType = '', this.headCount = 0,
                 this.liveWeightPerHeadKg = 0.0,
                 required this.photos});

  factory Listing.fromJson(Map<String, dynamic> json) => _$ListingFromJson(json);
  Map<String, dynamic> toJson() => _$ListingToJson(this);

  /// First photo URL or null — used by listing cards for the thumbnail. Returns null when there are no photos
  /// (UI falls back to a category icon or placeholder).
  String? get primaryPhotoUrl => photos.isEmpty ? null : photos.first.url;

  /// Display name for the active locale. Falls back to Uzbek for any non-RU language.
  String displayName(String languageCode) =>
      languageCode == 'ru' && nameRu.isNotEmpty ? nameRu : nameUz;

  /// True when the product is sold per-animal (one head at a time). UI uses this to switch the qty
  /// stepper from kg increments to head increments.
  bool get isByHead => isLiveAnimal && saleType == ListingSaleType.byHead;

  /// PRD §1 wholesale rule: 10kg minimum on BY_WEIGHT raw-meat listings; live-by-head has no minimum
  /// (you can buy 1 head). Used by the qty stepper + qty editor sheet so the rules live in ONE place.
  int get minOrderKg => isByHead ? 1 : 10;

  /// Step size for the qty stepper +/- buttons. For BY_HEAD it's 1 (one animal); for BY_WEIGHT we use 5
  /// per the PRD ("+5 or +10 kg increments"). Tap-and-hold or the typeable editor sheet is how a buyer
  /// jumps in larger chunks.
  int get stepKg => isByHead ? 1 : 5;
}
