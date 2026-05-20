// Cart state — in-memory CartNotifier owning a Map<productId, CartItem>. The cart is intentionally NOT persisted to
// SharedPreferences in this prototype phase: real orders go through the /orders API, so a long-lived local cart would
// just drift away from server reality. When the real listings + checkout endpoints land, we'll either persist with an
// optimistic-update layer or move the cart server-side entirely.
//
// API surface (kept narrow on purpose):
//   • add(product)           — adds qty 1, or +1 if already present
//   • setQty(productId, qty) — clamp to [0, ∞). qty 0 removes the row entirely
//   • setShopNote(text)      — single cart-level free-form note ("Do'konga izoh")
//   • clear()                — wipe everything (used after a successful checkout)
//
// Derived providers (cartItemCountProvider, cartTotalProvider) live below — UI binds to whichever is cheapest for its
// frame so we don't rebuild the full bottom bar on every qty change.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_products.dart';


/// One row in the cart. We hold a reference to the product itself (not just the id) so totals + display can be
/// computed without needing to re-look-up the catalog every frame. Swapping FakeProduct → Listing later is a
/// type-rename, not a logic change.
class CartItem {
  final FakeProduct product;
  final int qty;
  const CartItem({required this.product, required this.qty});

  CartItem copyWith({int? qty}) => CartItem(product: product, qty: qty ?? this.qty);

  /// Line subtotal — qty × per-kg price. Returns so'm as an int; UI formats with thousands separators.
  int get lineTotalSoum => qty * product.priceSoum;
}


/// Top-level cart state: items keyed by product id (preserves a stable display order — Dart maps are insertion-ordered)
/// plus the optional shop-level note the user can write before checkout.
class CartState {
  final Map<int, CartItem> items;
  final String shopNote;
  const CartState({required this.items, required this.shopNote});

  /// Initial empty state — used by the Notifier's super() constructor.
  const CartState.empty() : items = const {}, shopNote = '';

  /// Total unit-count across all rows. Used by the "N ta mahsulot" string on the floating bar.
  int get itemCount {
    var total = 0;
    for (final i in items.values) { total += i.qty; }
    return total;
  }

  /// Grand total in so'm. Iterated rather than reduce() for a tiny performance edge on rebuilds.
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


/// Owns the mutation logic. State is immutable; every mutation rebuilds a fresh Map so Riverpod's equality check
/// fires correctly. Map size is small (10s of items max), so the copy cost is irrelevant.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState.empty());

  /// First tap on a product card — start the row at qty 1. Subsequent taps would normally bump via setQty, but we keep
  /// add() idempotent-safe by +1ing if the row already exists (so accidental double-taps don't surprise the user).
  void add(FakeProduct product) {
    final existing = state.items[product.id];
    final next = Map<int, CartItem>.of(state.items);
    next[product.id] = existing == null
        ? CartItem(product: product, qty: 1)
        : existing.copyWith(qty: existing.qty + 1);
    state = state.copyWith(items: next);
  }

  /// Used by every qty-stepper UI. qty <= 0 removes the row (the user dragged below 1). The clamp at 99 is a soft cap
  /// preventing accidental thousands when someone holds the + button — real backend enforces its own listing-level cap.
  void setQty(int productId, int qty) {
    final next = Map<int, CartItem>.of(state.items);
    if (qty <= 0) {
      next.remove(productId);
    } else {
      final existing = next[productId];
      if (existing == null) return;  // ignore setQty on a missing row — should never happen, but defensive
      next[productId] = existing.copyWith(qty: qty.clamp(1, 99));
    }
    state = state.copyWith(items: next);
  }

  /// Free-form note that ships with the order ("Eshikni 3 marta taqillating", "Pichoq qoshmang", etc.).
  void setShopNote(String text) => state = state.copyWith(shopNote: text);

  /// Wipe after a successful checkout. Also used by the "empty cart" gesture in the Savat screen.
  void clear() => state = const CartState.empty();
}


// ---------- Providers ----------

/// Root provider — the cart itself.
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

/// Cheap derived providers — UI that only needs the count (the bottom bar badge) doesn't rebuild on every name/qty
/// change in a single row. select() narrows the rebuild surface to just the int.
final cartItemCountProvider = Provider<int>((ref) => ref.watch(cartProvider.select((s) => s.itemCount)));
final cartTotalSoumProvider = Provider<int>((ref) => ref.watch(cartProvider.select((s) => s.totalSoum)));
final cartHasItemsProvider = Provider<bool>((ref) => ref.watch(cartProvider.select((s) => s.isNotEmpty)));
