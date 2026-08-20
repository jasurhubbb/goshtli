// ProfileRepository — buyer business profile data. /auth/me/ stays in AuthRepository.
import '../../../core/network/api_client.dart';
import '../../../shared/models/buyer_profile.dart';
import '../../listings/data/listings_repository.dart' show ApiException;

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  // ---- buyer ----
  Future<BuyerProfile> getBuyerProfile() async {
    final r = await _api.dio.get('/buyers/me/');
    if (r.statusCode == 200)
      return BuyerProfile.fromJson(r.data as Map<String, dynamic>);
    throw ApiException('Buyer profile fetch failed (HTTP ${r.statusCode})');
  }

  Future<BuyerProfile> patchBuyerProfile({
    String? businessName,
    String? region,
    String? address,
  }) async {
    final r = await _api.dio.patch(
      '/buyers/me/',
      data: {
        'business_name': ?businessName,
        'region': ?region,
        'address': ?address,
      },
    );
    if (r.statusCode == 200)
      return BuyerProfile.fromJson(r.data as Map<String, dynamic>);
    throw ApiException('Buyer profile update failed (HTTP ${r.statusCode})');
  }
}
