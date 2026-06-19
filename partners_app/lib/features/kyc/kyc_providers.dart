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
      final list = (r.data as List).cast<Map<String, dynamic>>();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}


final kycDocsProvider =
    StateNotifierProvider<KycDocsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
        (ref) => KycDocsNotifier(ref));
