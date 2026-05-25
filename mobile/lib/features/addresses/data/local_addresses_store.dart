// LocalAddressesStore — SharedPreferences-backed CRUD for addresses saved by anonymous users.
//
// Anonymous users can browse + checkout the cart with a saved delivery address without ever registering. Their
// addresses live entirely on-device (SharedPreferences as a JSON array under `local_addresses_v1`); registering
// later does NOT auto-import them, so the user keeps a fresh server-side list after login. Future enhancement:
// offer "import your local addresses to your new account" right after registration.
//
// IDs:
//   • Backend addresses are positive integers (PostgreSQL bigserial).
//   • Local addresses use NEGATIVE integers (-1, -2, ...) so the two ranges never collide. If a UI surface
//     somehow shows both lists merged, ids stay unique. selectedAddressIdProvider survives login transitions
//     gracefully because a -1 id won't match any backend row, and selectedAddressProvider falls back to null.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'address_model.dart';


class LocalAddressesStore {
  static const _kKey = 'local_addresses_v1';

  /// Read the current list. Returns [] for first-time users + corrupted JSON (defensive).
  Future<List<Address>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((j) => Address.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      // Corrupted JSON — start fresh rather than crash. Production would also log to Sentry here.
      return [];
    }
  }

  /// Append a new row. Auto-generates a unique negative id so it doesn't collide with backend positive ids.
  Future<Address> create({
    required String label, required String address,
    String entrance = '', String floor = '', String apartment = '', String notes = '',
    double? lat, double? lng,
  }) async {
    final current = await list();
    var nextId = -1;
    for (final a in current) { if (a.id <= nextId) nextId = a.id - 1; }
    final created = Address(id: nextId, label: label, address: address,
        entrance: entrance, floor: floor, apartment: apartment, notes: notes,
        lat: lat, lng: lng, isDefault: current.isEmpty);
    await _writeAll([...current, created]);
    return created;
  }

  /// Patch — only fields present in `patch` are updated; everything else keeps its existing value.
  /// `lat`/`lng` come in as DRF-style stringified Decimals when called from the form; we parse them back.
  Future<Address> update(int id, Map<String, dynamic> patch) async {
    final current = await list();
    final updated = <Address>[];
    Address? touched;
    for (final a in current) {
      if (a.id != id) { updated.add(a); continue; }
      final fresh = Address(
        id: a.id,
        label: (patch['label'] as String?) ?? a.label,
        address: (patch['address'] as String?) ?? a.address,
        entrance: (patch['entrance'] as String?) ?? a.entrance,
        floor: (patch['floor'] as String?) ?? a.floor,
        apartment: (patch['apartment'] as String?) ?? a.apartment,
        notes: (patch['notes'] as String?) ?? a.notes,
        lat: patch['lat'] is String ? double.tryParse(patch['lat'] as String) : a.lat,
        lng: patch['lng'] is String ? double.tryParse(patch['lng'] as String) : a.lng,
        isDefault: a.isDefault,
      );
      updated.add(fresh);
      touched = fresh;
    }
    await _writeAll(updated);
    return touched ?? current.firstWhere((a) => a.id == id);
  }

  /// Hard-remove. Returns void to match the backend repo signature; UI is responsible for clearing any
  /// selectedAddressIdProvider pointer at this id afterwards.
  Future<void> delete(int id) async {
    final current = await list();
    final remaining = current.where((a) => a.id != id).toList();
    await _writeAll(remaining);
  }

  /// Serialize back to SharedPreferences. Single key, single string — small payload (~1KB even for many rows).
  Future<void> _writeAll(List<Address> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list.map((a) => a.toJson()).toList());
    await prefs.setString(_kKey, json);
  }
}
