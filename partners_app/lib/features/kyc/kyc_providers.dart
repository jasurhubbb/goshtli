import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';


/// Owner's KYC docs. Async list of {id, kind, image_url, is_approved}.
class KycDocsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  KycDocsNotifier(this._ref) : super(const AsyncValue.loading()) { refresh(); }

  Future<void> refresh() async {
    try {
      final api = _ref.read(apiClientProvider);
      final r = await api.dio.get('/kyc/me/');
      // Defensive: backend returns a List on 200, a Map (with `detail`) on 4xx error. Either way,
      // never let an unexpected shape crash the screen — fall back to an empty list.
      final raw = r.data;
      final list = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}


final kycDocsProvider =
    StateNotifierProvider<KycDocsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
        (ref) => KycDocsNotifier(ref));
