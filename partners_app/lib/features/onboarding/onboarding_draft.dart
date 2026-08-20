/// Onboarding draft — typed payload built up across the wizard pages and POSTed to the backend on
/// final submit. Onboarding is qassob-only; internal catalog operators are provisioned by the
/// platform and go directly to their workspace.
///
/// Persisted to SharedPreferences (key `onboarding_draft`) so backgrounding mid-wizard doesn't lose
/// progress.
class OnboardingDraft {
  final String fullName;
  final List<String> animalsSupported;
  final double? lat;
  final double? lng;
  final String region;
  final String address;
  final String? photoPath;

  final int yearsExperience;
  final int dailyCapacityHead;
  final bool isSlaughterhouse;

  const OnboardingDraft({
    this.fullName = '',
    this.animalsSupported = const [],
    this.lat,
    this.lng,
    this.region = '',
    this.address = '',
    this.photoPath,
    this.yearsExperience = 0,
    this.dailyCapacityHead = 10,
    this.isSlaughterhouse = false,
  });

  OnboardingDraft copyWith({
    String? fullName,
    List<String>? animalsSupported,
    double? lat,
    double? lng,
    String? region,
    String? address,
    String? photoPath,
    int? yearsExperience,
    int? dailyCapacityHead,
    bool? isSlaughterhouse,
  }) =>
      OnboardingDraft(
        fullName: fullName ?? this.fullName,
        animalsSupported: animalsSupported ?? this.animalsSupported,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        region: region ?? this.region,
        address: address ?? this.address,
        photoPath: photoPath ?? this.photoPath,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        dailyCapacityHead: dailyCapacityHead ?? this.dailyCapacityHead,
        isSlaughterhouse: isSlaughterhouse ?? this.isSlaughterhouse,
      );

  Map<String, dynamic> toQassobPayload() => {
        'full_name': fullName,
        'years_experience': yearsExperience,
        'region': region.isEmpty ? 'Tashkent' : region,
        'address': address.isEmpty ? '—' : address,
        if (lat != null) 'lat': lat!.toStringAsFixed(6),
        if (lng != null) 'lng': lng!.toStringAsFixed(6),
        'animals_supported': animalsSupported,
        'is_slaughterhouse': isSlaughterhouse,
        'daily_capacity_head': dailyCapacityHead,
      };

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'animalsSupported': animalsSupported,
        'lat': lat,
        'lng': lng,
        'region': region,
        'address': address,
        'photoPath': photoPath,
        'yearsExperience': yearsExperience,
        'dailyCapacityHead': dailyCapacityHead,
        'isSlaughterhouse': isSlaughterhouse,
      };

  factory OnboardingDraft.fromJson(Map<String, dynamic> j) => OnboardingDraft(
        fullName: j['fullName'] as String? ?? '',
        animalsSupported:
            (j['animalsSupported'] as List?)?.cast<String>() ?? const [],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        region: j['region'] as String? ?? '',
        address: j['address'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        yearsExperience: j['yearsExperience'] as int? ?? 0,
        dailyCapacityHead: j['dailyCapacityHead'] as int? ?? 10,
        isSlaughterhouse: j['isSlaughterhouse'] as bool? ?? false,
      );
}
