import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted role marker for the qassob profile wizard. Internal catalog operators never enter
/// onboarding, even though their backend compatibility role remains SUPPLIER.
class RoleDraftNotifier extends StateNotifier<UserRole?> {
  RoleDraftNotifier() : super(null) {
    _load();
  }

  static const _kKey = 'partner_role_draft';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_kKey);
    if (code == 'QASSOB') state = UserRole.qassob;
  }

  Future<void> set(UserRole r) async {
    state = r;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, roleToWire(r));
  }

  Future<void> clear() async {
    state = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}

final roleDraftProvider = StateNotifierProvider<RoleDraftNotifier, UserRole?>(
    (ref) => RoleDraftNotifier());
