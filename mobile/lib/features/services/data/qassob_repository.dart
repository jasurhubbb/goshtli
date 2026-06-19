import '../../../core/network/api_client.dart';
import 'qassob_models.dart';


class QassobRepository {
  final ApiClient _api;
  QassobRepository(this._api);

  /// GET /qassobs/ — public. Animal filter, optional buyer lat/lng for distance sort, optional
  /// `service=slaughter` for the qushxona section.
  Future<List<Qassob>> list({
    String? animal,
    String? service,
    double? buyerLat,
    double? buyerLng,
  }) async {
    final qp = <String, dynamic>{};
    if (animal != null && animal.isNotEmpty) qp['animal'] = animal;
    if (service != null && service.isNotEmpty) qp['service'] = service;
    if (buyerLat != null) qp['buyer_lat'] = buyerLat.toStringAsFixed(6);
    if (buyerLng != null) qp['buyer_lng'] = buyerLng.toStringAsFixed(6);
    final r = await _api.dio.get('/qassobs/', queryParameters: qp);
    final list = (r.data as List).cast<Map<String, dynamic>>();
    return list.map(Qassob.fromJson).toList();
  }

  Future<Qassob> getById(int id) async {
    final r = await _api.dio.get('/qassobs/$id/');
    return Qassob.fromJson(r.data as Map<String, dynamic>);
  }
}
