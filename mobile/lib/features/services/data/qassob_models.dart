/// Qassob (butcher) summary as returned by the public list endpoint.
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
  });

  factory Qassob.fromJson(Map<String, dynamic> j) => Qassob(
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
  );
}
