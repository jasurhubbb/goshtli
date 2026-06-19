/// Onboarding draft — typed payload built up across the wizard pages and POSTed to the backend on
/// final submit. Both Qassob and Supplier wizards write into the SAME shape; final submit branches on
/// `roleDraftProvider`.
///
/// Persisted to SharedPreferences (key `onboarding_draft`) so backgrounding mid-wizard doesn't lose
/// progress.
class OnboardingDraft {
  // ---- Common across both roles ----
  final String fullName;
  final List<String> animalsSupported;
  final double? lat;
  final double? lng;
  final String region;
  final String address;
  final String? photoPath;

  // ---- Qassob-only ----
  final int yearsExperience;
  final int dailyCapacityHead;
  final bool isSlaughterhouse;

  // ---- Supplier-only ----
  final String companyName;
  /// Per-animal: {"MOL": ["LIVE","CUT"], "QOY": ["CUT"]}
  final Map<String, List<String>> deliveryModes;
  final bool selfDelivers;
  final List<String> vehicleTypes;
  final String vehiclePlate;

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
    this.companyName = '',
    this.deliveryModes = const {},
    this.selfDelivers = false,
    this.vehicleTypes = const [],
    this.vehiclePlate = '',
  });

  OnboardingDraft copyWith({
    String? fullName, List<String>? animalsSupported,
    double? lat, double? lng, String? region, String? address, String? photoPath,
    int? yearsExperience, int? dailyCapacityHead, bool? isSlaughterhouse,
    String? companyName, Map<String, List<String>>? deliveryModes,
    bool? selfDelivers, List<String>? vehicleTypes, String? vehiclePlate,
  }) => OnboardingDraft(
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
    companyName: companyName ?? this.companyName,
    deliveryModes: deliveryModes ?? this.deliveryModes,
    selfDelivers: selfDelivers ?? this.selfDelivers,
    vehicleTypes: vehicleTypes ?? this.vehicleTypes,
    vehiclePlate: vehiclePlate ?? this.vehiclePlate,
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

  Map<String, dynamic> toSupplierPayload() => {
    'business_name': companyName.isEmpty ? fullName : companyName,
    'full_name': fullName,
    'region': region.isEmpty ? 'Tashkent' : region,
    'address': address.isEmpty ? '—' : address,
    if (lat != null) 'lat': lat!.toStringAsFixed(6),
    if (lng != null) 'lng': lng!.toStringAsFixed(6),
    'animals_supported': animalsSupported,
    'delivery_modes': deliveryModes,
    'self_delivers': selfDelivers,
    if (selfDelivers) 'vehicle_types': vehicleTypes,
    if (selfDelivers) 'vehicle_plate': vehiclePlate,
  };

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'animalsSupported': animalsSupported,
    'lat': lat, 'lng': lng,
    'region': region, 'address': address,
    'photoPath': photoPath,
    'yearsExperience': yearsExperience,
    'dailyCapacityHead': dailyCapacityHead,
    'isSlaughterhouse': isSlaughterhouse,
    'companyName': companyName,
    'deliveryModes': deliveryModes,
    'selfDelivers': selfDelivers,
    'vehicleTypes': vehicleTypes,
    'vehiclePlate': vehiclePlate,
  };

  factory OnboardingDraft.fromJson(Map<String, dynamic> j) => OnboardingDraft(
    fullName: j['fullName'] as String? ?? '',
    animalsSupported: (j['animalsSupported'] as List?)?.cast<String>() ?? const [],
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    region: j['region'] as String? ?? '',
    address: j['address'] as String? ?? '',
    photoPath: j['photoPath'] as String?,
    yearsExperience: j['yearsExperience'] as int? ?? 0,
    dailyCapacityHead: j['dailyCapacityHead'] as int? ?? 10,
    isSlaughterhouse: j['isSlaughterhouse'] as bool? ?? false,
    companyName: j['companyName'] as String? ?? '',
    deliveryModes: ((j['deliveryModes'] as Map?) ?? {}).map((k, v) =>
        MapEntry(k as String, (v as List).cast<String>())),
    selfDelivers: j['selfDelivers'] as bool? ?? false,
    vehicleTypes: (j['vehicleTypes'] as List?)?.cast<String>() ?? const [],
    vehiclePlate: j['vehiclePlate'] as String? ?? '',
  );
}
