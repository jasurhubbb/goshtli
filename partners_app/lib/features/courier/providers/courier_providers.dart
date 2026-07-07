import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../data/courier_models.dart';
import '../data/courier_repository.dart';


/// Repository singleton — kept tiny for testability.
final courierRepoProvider = Provider<CourierRepository>((ref) =>
    CourierRepository(ref.watch(apiClientProvider)));


/// KPI aggregate for the home tab. Refreshed on tab open + when FCM live-refresh fires.
final courierDashboardProvider = FutureProvider.autoDispose<CourierDashboard?>((ref) async {
  return ref.read(courierRepoProvider).dashboard();
});


/// Delivery list keyed by bucket string ('queue', 'active', 'done'). Each tab has its own
/// family entry — invalidating one bucket doesn't clobber the others.
final deliveriesProvider = FutureProvider.autoDispose.family<List<DeliveryRow>, String>(
    (ref, bucket) async {
  return ref.read(courierRepoProvider).deliveries(bucket);
});


/// Detail fetch for the delivery detail screen. autoDispose so leaving the page frees the row.
final deliveryDetailProvider = FutureProvider.autoDispose.family<DeliveryDetail?, int>(
    (ref, id) async {
  return ref.read(courierRepoProvider).deliveryDetail(id);
});


/// Profile fetch for the Profile tab. Invalidated on save.
final courierMeProvider = FutureProvider.autoDispose<CourierProfile?>((ref) async {
  return ref.read(courierRepoProvider).me();
});


/// Earnings — keyed by period ('day', 'week', 'month').
final earningsProvider = FutureProvider.autoDispose.family<EarningsResult?, String>(
    (ref, period) async {
  return ref.read(courierRepoProvider).earnings(period: period);
});
