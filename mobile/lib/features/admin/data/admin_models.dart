// Admin-facing models — full CRUD shapes for MeatCategory + Market. Distinct from the compact summary
// embeds in shared/models/listing.dart because the admin page needs id + is_active + display_order, none
// of which the buyer-side summary embeds carry.
//
// Kept as plain classes (no json_serializable codegen) — these are admin-only surfaces with limited fields,
// and writing fromJson by hand keeps the diff small + avoids a build_runner pass.


class AdminCategory {
  final int id;
  final String slug;
  final String nameUz;
  final String nameRu;
  final String imageUrl;
  final int displayOrder;
  final bool isActive;

  const AdminCategory({required this.id, required this.slug, required this.nameUz, required this.nameRu,
      required this.imageUrl, required this.displayOrder, required this.isActive});

  factory AdminCategory.fromJson(Map<String, dynamic> j) => AdminCategory(
    id: (j['id'] as num).toInt(),
    slug: j['slug'] as String? ?? '',
    nameUz: j['name_uz'] as String? ?? '',
    nameRu: j['name_ru'] as String? ?? '',
    imageUrl: j['image_url'] as String? ?? '',
    displayOrder: ((j['display_order'] as num?) ?? 100).toInt(),
    isActive: j['is_active'] as bool? ?? true,
  );
}


class AdminMarket {
  final int id;
  final String slug;
  final String nameUz;
  final String nameRu;
  final String region;
  final String address;
  final String phone;
  final String logoUrl;
  final bool isActive;
  /// Backing SUPPLIER user id auto-created on the backend when this Market was POSTed. The Bozor detail
  /// screen uses this to filter "listings for this market" via the buyer-side /listings/?market=<slug> query.
  final int? ownerUserId;

  const AdminMarket({required this.id, required this.slug, required this.nameUz, required this.nameRu,
      required this.region, required this.address, required this.phone, required this.logoUrl,
      required this.isActive, this.ownerUserId});

  factory AdminMarket.fromJson(Map<String, dynamic> j) => AdminMarket(
    id: (j['id'] as num).toInt(),
    slug: j['slug'] as String? ?? '',
    nameUz: j['name_uz'] as String? ?? '',
    nameRu: j['name_ru'] as String? ?? '',
    region: j['region'] as String? ?? '',
    address: j['address'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    logoUrl: j['logo_url'] as String? ?? '',
    isActive: j['is_active'] as bool? ?? true,
    ownerUserId: (j['owner_user_id'] as num?)?.toInt(),
  );
}
