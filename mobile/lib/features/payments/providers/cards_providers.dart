// Cards providers — repository + the list-of-saved-cards async state.
//
// The list is held in a StateNotifier (not a FutureProvider) so add/delete mutations can update state
// synchronously — same pattern as addressesProvider — without the picker briefly flashing "no cards"
// during an invalidate-then-reload cycle.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show apiClientProvider;
import '../data/card_model.dart';
import '../data/cards_repository.dart';


final cardsRepositoryProvider = Provider<CardsRepository>((ref) =>
    CardsRepository(ref.watch(apiClientProvider)));


/// Async holder for the buyer's saved cards. Initial load fires once at construction; mutations
/// (add/delete/setDefault) update state inline so picker UI never blinks during a write.
class CardsNotifier extends StateNotifier<AsyncValue<List<PaymentCard>>> {
  final CardsRepository _repo;
  CardsNotifier(this._repo) : super(const AsyncValue.loading()) { refresh(); }

  Future<void> refresh() async {
    try {
      final list = await _repo.list();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Append a freshly-created card. If the new card came back is_default=true (first-card auto-default
  /// or make_default flag), strip the flag off any existing rows so the UI doesn't briefly show two
  /// defaults before the next refresh.
  Future<PaymentCard> add({
    required String pan,
    required int expiresMonth,
    required int expiresYear,
    required String cvc,
    String holderName = '',
    String phoneForSms = '',
    bool makeDefault = false,
  }) async {
    final created = await _repo.add(
      pan: pan, expiresMonth: expiresMonth, expiresYear: expiresYear, cvc: cvc,
      holderName: holderName, phoneForSms: phoneForSms, makeDefault: makeDefault,
    );
    final current = state.value ?? const <PaymentCard>[];
    final next = [created, ...current.map((c) => created.isDefault
        ? PaymentCard(id: c.id, last4: c.last4, brand: c.brand,
            expiresMonth: c.expiresMonth, expiresYear: c.expiresYear,
            holderName: c.holderName, phoneForSms: c.phoneForSms,
            isDefault: false, createdAt: c.createdAt)
        : c)];
    state = AsyncValue.data(next);
    return created;
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    final current = state.value ?? const <PaymentCard>[];
    state = AsyncValue.data(current.where((c) => c.id != id).toList());
  }

  Future<void> setDefault(int id) async {
    final fresh = await _repo.setDefault(id);
    state = AsyncValue.data(fresh);
  }
}


final cardsProvider = StateNotifierProvider<CardsNotifier, AsyncValue<List<PaymentCard>>>((ref) {
  return CardsNotifier(ref.watch(cardsRepositoryProvider));
});


/// Cheap helper — the default card, or null if the buyer has none. Picker preselects this on open.
final defaultCardProvider = Provider<PaymentCard?>((ref) {
  final list = ref.watch(cardsProvider).value ?? const <PaymentCard>[];
  for (final c in list) { if (c.isDefault) return c; }
  return list.isEmpty ? null : list.first;
});
