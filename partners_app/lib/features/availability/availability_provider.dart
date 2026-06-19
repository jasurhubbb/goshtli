import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/network/providers.dart';


/// F1 Open/Closed toggle. Reads the current `is_open_now` from the dashboard payload + writes via
/// the appropriate role-specific endpoint.
class AvailabilityNotifier extends StateNotifier<bool> {
  final Ref _ref;
  AvailabilityNotifier(this._ref, super.initial);

  Future<void> setOpen(bool v) async {
    state = v;
    try {
      final auth = _ref.read(partnerAuthProvider);
      if (auth is! AuthAuthenticated) return;
      final api = _ref.read(apiClientProvider);
      if (auth.user.isQassob) {
        await api.dio.post('/qassobs/me/availability/', data: {'is_open_now': v});
      } else {
        await api.dio.post('/partner/suppliers/me/availability/', data: {'is_open_now': v});
      }
    } catch (_) {
      // Rollback on failure
      state = !v;
    }
  }
}


final availabilityProvider = StateNotifierProvider<AvailabilityNotifier, bool>(
    (ref) => AvailabilityNotifier(ref, true));
