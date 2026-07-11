// Single choke point for "add to cart" so the one-product-per-cart rule lives in exactly one place.
//
// v3.9.16 — a buyer can only order ONE product at a time (each product is its own order). Trying to add a
// SECOND, different product shows a production-style "one at a time" dialog offering to replace the current
// item. Adding more of the SAME product just bumps its quantity as usual.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../providers/cart_providers.dart';


/// Adds [listing] to the cart, enforcing the single-product rule. If a different product is already in the
/// cart, prompts the buyer to replace it. Returns true if the listing ended up in the cart (added or
/// replaced), false if the buyer cancelled — callers use this to decide whether to pop / navigate on.
Future<bool> addToCartOrPrompt(BuildContext context, WidgetRef ref, Listing listing) async {
  final cart = ref.read(cartProvider);
  // No conflict (empty cart, or the same product) → add straight away.
  if (!cart.conflictsWith(listing.id)) {
    ref.read(cartProvider.notifier).add(listing);
    return true;
  }
  // A different product is already in the cart — ask before replacing (Uber-Eats / Wolt "start new order").
  final current = cart.items[cart.soleListingId]?.listing;
  final replace = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // Explicit white surface + dark text: the app's cream/off-white theme was rendering the default
      // dialog text too light against a near-white surface, so the message was hard to read.
      backgroundColor: Colors.white,
      titleTextStyle: const TextStyle(
          color: Color(0xFF1A1A1A), fontSize: 18, fontWeight: FontWeight.w900),
      contentTextStyle: const TextStyle(
          color: Color(0xFF2A2A2A), fontSize: 15, height: 1.35),
      title: const Text('Bir vaqtda bitta mahsulot'),
      content: Text(current == null
          ? "Savatingizda boshqa mahsulot bor. Har bir buyurtma faqat bitta mahsulotdan iborat. Uni almashtirasizmi?"
          : "Savatingizda \"${current.nameUz}\" bor. Har bir buyurtma faqat bitta mahsulotdan iborat.\n\n"
            "Uni \"${listing.nameUz}\" bilan almashtirasizmi?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Yo'q")),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Almashtirish')),
      ],
    ),
  );
  if (replace == true) {
    ref.read(cartProvider.notifier).replaceWith(listing);
    return true;
  }
  return false;
}
