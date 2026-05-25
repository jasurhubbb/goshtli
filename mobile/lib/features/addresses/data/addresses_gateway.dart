// AddressesGateway — single dispatcher for "save / list / update / delete an address" that picks the right
// backing store based on current auth state.
//
//   • Authenticated user → AddressesRepository (POST/GET/PATCH/DELETE /api/v1/buyers/addresses/)
//   • Anonymous user     → LocalAddressesStore (SharedPreferences JSON array)
//
// Why a gateway, not a switch inside each call site? The form / sheet code shouldn't know which store handles
// its operation — they just say "save this address". The same surface works for both user types, so the UI
// can keep the "no login required" guarantee for anonymous users without scattering auth checks throughout.
//
// Transition behaviour: if a user is anonymous, saves a few local addresses, then signs in — the gateway
// switches to backend mode. The local addresses are still ON DEVICE (we don't auto-sync), they're just
// invisible to the UI because addressesProvider now reads from the backend. A future enhancement would offer
// "import your saved addresses to your new account" right after a fresh registration.
import '../../auth/providers/auth_state.dart';
import 'address_model.dart';
import 'addresses_repository.dart';
import 'local_addresses_store.dart';


class AddressesGateway {
  // Captured at construction time, NOT looked up per-call. Riverpod re-builds the gateway provider when auth
  // changes, so the boolean is always current when this instance is in scope.
  final bool _useBackend;
  final AddressesRepository _backend;
  final LocalAddressesStore _local;

  AddressesGateway({required AuthState auth,
                    required AddressesRepository backend, required LocalAddressesStore local})
      : _useBackend = auth is AuthAuthenticated, _backend = backend, _local = local;

  Future<List<Address>> list() => _useBackend ? _backend.list() : _local.list();

  Future<Address> create({required String label, required String address,
                          String entrance = '', String floor = '', String apartment = '', String notes = '',
                          double? lat, double? lng}) {
    if (_useBackend) {
      return _backend.create(label: label, address: address, entrance: entrance, floor: floor,
          apartment: apartment, notes: notes, lat: lat, lng: lng);
    }
    return _local.create(label: label, address: address, entrance: entrance, floor: floor,
        apartment: apartment, notes: notes, lat: lat, lng: lng);
  }

  Future<Address> update(int id, Map<String, dynamic> patch) {
    if (_useBackend) return _backend.update(id, patch);
    return _local.update(id, patch);
  }

  Future<void> delete(int id) {
    if (_useBackend) return _backend.delete(id);
    return _local.delete(id);
  }
}
