// DashboardRepository — fetches /api/v1/buyers/dashboard/ or /api/v1/suppliers/dashboard/ depending on caller role.
import '../../../core/network/api_client.dart';
import '../../listings/data/listings_repository.dart' show ApiException;  // shared exception type
import 'dashboard_models.dart';


class DashboardRepository {
  final ApiClient _api;
  DashboardRepository(this._api);

  Future<BuyerDashboard> buyer() async {
    final r = await _api.dio.get('/buyers/dashboard/');
    if (r.statusCode == 200) return BuyerDashboard.fromJson(r.data as Map<String, dynamic>);
    throw ApiException('Buyer dashboard failed (HTTP ${r.statusCode})');
  }

  Future<SupplierDashboard> supplier() async {
    final r = await _api.dio.get('/suppliers/dashboard/');
    if (r.statusCode == 200) return SupplierDashboard.fromJson(r.data as Map<String, dynamic>);
    throw ApiException('Supplier dashboard failed (HTTP ${r.statusCode})');
  }
}
