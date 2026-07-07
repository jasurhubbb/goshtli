/// Public-facing supplier profile shape — matches `SupplierPublicSerializer` on the backend.
///
/// Used by the buyer-app supplier profile page (reached from ListingDetailScreen). Empty strings
/// on the optional fields (photo_url, phone) are the "unset" sentinel we render as `.isEmpty`
/// checks.
class SupplierPublic {
  final int userId;
  final String fullName;
  final String businessName;
  final String region;
  final String address;
  final String phone;
  final String photoUrl;
  final int listingsCount;
  final String createdAt;

  const SupplierPublic({
    required this.userId,
    required this.fullName,
    required this.businessName,
    required this.region,
    required this.address,
    required this.phone,
    required this.photoUrl,
    required this.listingsCount,
    required this.createdAt,
  });

  factory SupplierPublic.fromJson(Map<String, dynamic> j) => SupplierPublic(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        fullName: (j['full_name'] ?? '') as String,
        businessName: (j['business_name'] ?? '') as String,
        region: (j['region'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        photoUrl: (j['photo_url'] ?? '') as String,
        listingsCount: (j['listings_count'] as num?)?.toInt() ?? 0,
        createdAt: (j['created_at'] ?? '') as String,
      );
}
