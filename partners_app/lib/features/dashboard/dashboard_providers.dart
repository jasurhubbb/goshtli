import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';


/// Polled every ~60s on the Bosh sahifa. Bundle endpoint so 1 call covers all KPI tiles.
class DashboardNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref _ref;
  DashboardNotifier(this._ref) : super(const AsyncValue.loading()) { refresh(); }

  Future<void> refresh() async {
    try {
      final r = await _ref.read(apiClientProvider).dio.get('/partner/dashboard/');
      state = AsyncValue.data(Map<String, dynamic>.from(r.data as Map));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}


final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<Map<String, dynamic>>>(
    (ref) => DashboardNotifier(ref));


/// Smart tips for F12 — upcoming UZ holidays + seasonality nudges.
class SmartTipsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  SmartTipsNotifier(this._ref) : super(const AsyncValue.loading()) { refresh(); }

  Future<void> refresh() async {
    try {
      final r = await _ref.read(apiClientProvider).dio.get('/partner/smart-tips/');
      final tips = ((r.data as Map)['tips'] as List).cast<Map<String, dynamic>>();
      state = AsyncValue.data(tips);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}


final smartTipsProvider = StateNotifierProvider<SmartTipsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
    (ref) => SmartTipsNotifier(ref));
