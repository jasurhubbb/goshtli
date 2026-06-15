// Cart state — in-memory CartNotifier owning a Map<listingId, CartItem>. Not persisted to SharedPreferences in
// v3.1 (real orders go through the /orders API; a long-lived local cart would just drift away from server reality).
// When the real listings + checkout endpoints are fully wired, persistence + optimistic updates can come together.
//
// API surface:
//   • add(listing)           — adds qty 1, or +1 if already present
//   • setQty(listingId, qty) — clamp to [0, 99]. qty 0 removes the row entirely
//   • setShopNote(text)      — single cart-level free-form note ("Do'konga izoh")
//   • clear()                — wipe everything (used after a successful checkout)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';


/// One row in the cart. Holds a reference to the full Listing (not just its id) so totals + display can be
/// computed without re-fetching the catalog per render. The Listing is a snapshot taken at add-to-cart time —
/// if price changes server-side before checkout, the checkout endpoint will reconcile.
class CartItem {
  final Listing listing;
  final int qty;
  const CartItem({required this.listing, required this.qty});

  CartItem copyWith({int? qty}) => CartItem(listing: listing, qty: qty ?? this.qty);

  /// Line subtotal — qty × per-kg price. Returns so'm as an int (we round at the line level; backend always
  /// re-computes the authoritative total at checkout).
  int get lineTotalSoum => qty * listing.pricePerKg.round();
}


/// Top-level cart state: items keyed by listing id (insertion-ordered map preserves display order).
class CartState {
  final Map<int, CartItem> items;
  final String shopNote;
  const CartState({required this.items, required this.shopNote});

  const CartState.empty() : items = const {}, shopNote = '';

  /// Total unit count across all rows. Powers the "N ta mahsulot" badge on the floating bar.
  int get itemCount {
    var total = 0;
    for (final i in items.values) { total += i.qty; }
    return total;
  }

  /// Grand total in so'm. Iterated rather than reduce() for a tiny rebuild-cost edge.
  int get totalSoum {
    var total = 0;
    for (final i in items.values) { total += i.lineTotalSoum; }
    return total;
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({Map<int, CartItem>? items, String? shopNote}) =>
      CartState(items: items ?? this.items, shopNote: shopNote ?? this.shopNote);
}


/// Owns the mutation logic. State is immutable; every mutation rebuilds a fresh Map so Riverpod's equality
/// check fires correctly. Map size is small (10s of items max), so the copy cost is irrelevant.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState.empty());

  /// First tap on a product card. PRD v2 §1: for BY_WEIGHT (raw meat / live by kg) the first tap jumps
  /// straight to the 10kg wholesale minimum — buyers ordering 100kg shouldn't have to tap "+" 100 times.
  /// For BY_HEAD (live qo'y / mol per head) we start at 1 (one animal).
  /// Subsequent calls on an already-present row bump by the listing's `stepKg` (5kg for raw meat, 1 head
  /// for live-by-head).
  void add(Listing listing) {
    final existing = state.items[listing.id];
    final next = Map<int, CartItem>.of(state.items);
    if (existing == null) {
      // First add → land on the minimum order quantity, NOT 1. This is the "press +, jump to 10" UX rule.
      next[listing.id] = CartItem(listing: listing, qty: listing.minOrderKg);
    } else {
      next[listing.id] = existing.copyWith(qty: existing.qty + listing.stepKg);
    }
    state = state.copyWith(items: next);
  }

  /// Used by every qty-stepper UI's +/- and the typeable editor sheet's confirm. Anything <= 0 removes the
  /// row entirely (the buyer subtracted past the minimum). Clamp at 9999 — backend cap is much higher but
  /// no real cart line needs more.
  void setQty(int listingId, int qty) {
    final next = Map<int, CartItem>.of(state.items);
    if (qty <= 0) {
      next.remove(listingId);
    } else {
      final existing = next[listingId];
      if (existing == null) return;
      next[listingId] = existing.copyWith(qty: qty.clamp(1, 9999));
    }
    state = state.copyWith(items: next);
  }

  /// PRD-compliant "+" handler — bumps by the listing's stepKg. Stepper buttons call THIS rather than
  /// `setQty(qty + 1)` so the rule lives in one place. Underflow (going below minOrderKg with the "-")
  /// is handled separately: see decByStep().
  void incByStep(int listingId) {
    final existing = state.items[listingId];
    if (existing == null) return;
    setQty(listingId, existing.qty + existing.listing.stepKg);
  }

  /// "-" handler — drops by stepKg, but if that takes us below the listing's min order, remove the row
  /// entirely (the buyer essentially abandoned the line). This avoids the buyer being "stuck" at the
  /// minimum with no way to remove the item using the stepper.
  void decByStep(int listingId) {
    final existing = state.items[listingId];
    if (existing == null) return;
    final next = existing.qty - existing.listing.stepKg;
    setQty(listingId, next < existing.listing.minOrderKg ? 0 : next);
  }

  /// Free-form note that ships with the order ("Eshikni 3 marta taqillating", "Pichoq qoshmang", etc.).
  void setShopNote(String text) => state = state.copyWith(shopNote: text);

  /// Wipe after a successful checkout. Also used by the "empty cart" gesture in the Savat screen.
  void clear() => state = const CartState.empty();
}


// ---------- Providers ----------

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

/// Cheap derived providers — UI that only needs the count (the bottom bar badge) doesn't rebuild on every
/// name/qty change in a single row. select() narrows the rebuild surface to just the int / bool.
final cartItemCountProvider = Provider<int>((ref) => ref.watch(cartProvider.select((s) => s.itemCount)));
final cartTotalSoumProvider = Provider<int>((ref) => ref.watch(cartProvider.select((s) => s.totalSoum)));
final cartHasItemsProvider = Provider<bool>((ref) => ref.watch(cartProvider.select((s) => s.isNotEmpty)));
