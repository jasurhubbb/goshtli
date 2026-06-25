/// Qassob (butcher) shape as returned by the public list + detail endpoints.
///
/// v3.9: the detail endpoint also includes the service-profile fields the partner-app Servisim CRUD
/// owns (bio / specialties / certifications / working_hours / price_list / languages / gallery).
/// The list endpoint returns the same shape (cheap on the backend, lets the buyer's tab show a
/// "Halal · Qurbonlik" specialty preview on each card without a per-card detail roundtrip).
class Qassob {
  final int id;
  final String fullName;
  final int yearsExperience;
  final String region;
  final String address;
  final List<String> animalsSupported;
  final bool isSlaughterhouse;
  final String photoUrl;
  final String phone;
  final String telegram;
  final bool isOpenNow;
  final double ratingAvg;
  final int ratingCount;
  final double? distanceKm;

  // v3.9 — service-profile fields. All nullable / empty defaults so a v3.8 qassob that hasn't filled
  // out Servisim still renders cleanly (the card just omits the specialty chips, etc).
  final String bio;
  final List<String> specialties;
  final List<String> languages;
  final List<QassobCertification> certifications;
  final Map<String, List<int>?> workingHours;
  final List<QassobPriceRow> priceList;
  final List<QassobGalleryPhoto> gallery;

  const Qassob({
    required this.id,
    required this.fullName,
    required this.yearsExperience,
    required this.region,
    required this.address,
    required this.animalsSupported,
    required this.isSlaughterhouse,
    required this.photoUrl,
    required this.phone,
    required this.telegram,
    required this.isOpenNow,
    required this.ratingAvg,
    required this.ratingCount,
    this.distanceKm,
    this.bio = '',
    this.specialties = const [],
    this.languages = const [],
    this.certifications = const [],
    this.workingHours = const {},
    this.priceList = const [],
    this.gallery = const [],
  });

  factory Qassob.fromJson(Map<String, dynamic> j) {
    // Each nested-list parse runs through its own dedicated parser so a malformed row from the
    // backend (e.g. an old build's response missing a `unit` key) only blanks that row, not the
    // whole detail page.
    final whRaw = (j['working_hours'] as Map?) ?? const {};
    final wh = <String, List<int>?>{};
    whRaw.forEach((k, v) {
      if (v == null) { wh[k.toString()] = null; return; }
      if (v is List && v.length == 2 && v[0] is num && v[1] is num) {
        wh[k.toString()] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
      }
    });
    return Qassob(
      id: j['id'] as int,
      fullName: (j['full_name'] ?? '') as String,
      yearsExperience: (j['years_experience'] ?? 0) as int,
      region: (j['region'] ?? '') as String,
      address: (j['address'] ?? '') as String,
      animalsSupported: ((j['animals_supported'] as List?) ?? const []).cast<String>(),
      isSlaughterhouse: (j['is_slaughterhouse'] ?? false) as bool,
      photoUrl: (j['photo_url'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      telegram: (j['telegram'] ?? '') as String,
      isOpenNow: (j['is_open_now'] ?? true) as bool,
      ratingAvg: double.tryParse(j['rating_avg']?.toString() ?? '') ?? 0,
      ratingCount: (j['rating_count'] ?? 0) as int,
      distanceKm: j['distance_km'] == null
          ? null : double.tryParse(j['distance_km'].toString()),
      bio: (j['bio'] ?? '') as String,
      specialties: ((j['specialties'] as List?) ?? const []).map((e) => e.toString()).toList(),
      languages: ((j['languages'] as List?) ?? const []).map((e) => e.toString()).toList(),
      certifications: ((j['certifications'] as List?) ?? const [])
          .map((e) => QassobCertification.fromJson(e as Map<String, dynamic>)).toList(),
      workingHours: wh,
      priceList: ((j['price_list'] as List?) ?? const [])
          .map((e) => QassobPriceRow.fromJson(e as Map<String, dynamic>)).toList(),
      gallery: ((j['gallery'] as List?) ?? const [])
          .map((e) => QassobGalleryPhoto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}


class QassobCertification {
  final String name;
  final int? year;
  const QassobCertification({required this.name, this.year});
  factory QassobCertification.fromJson(Map<String, dynamic> j) => QassobCertification(
        name: (j['name'] ?? '').toString(),
        year: j['year'] == null ? null : int.tryParse(j['year'].toString()),
      );
}


class QassobPriceRow {
  final String service;
  final int priceUzs;
  final String unit;
  const QassobPriceRow({required this.service, required this.priceUzs, required this.unit});
  factory QassobPriceRow.fromJson(Map<String, dynamic> j) => QassobPriceRow(
        service: (j['service'] ?? '').toString(),
        priceUzs: int.tryParse(j['price_uzs']?.toString() ?? '0') ?? 0,
        unit: (j['unit'] ?? '').toString(),
      );
}


class QassobGalleryPhoto {
  final int id;
  final String imageUrl;
  final String caption;
  final int position;
  const QassobGalleryPhoto({
    required this.id, required this.imageUrl, required this.caption, required this.position,
  });
  factory QassobGalleryPhoto.fromJson(Map<String, dynamic> j) => QassobGalleryPhoto(
        id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        imageUrl: (j['image_url'] ?? '') as String,
        caption: (j['caption'] ?? '') as String,
        position: int.tryParse(j['position']?.toString() ?? '0') ?? 0,
      );
}
