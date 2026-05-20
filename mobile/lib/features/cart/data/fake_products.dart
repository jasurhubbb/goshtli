// FakeProduct — disposable prototype catalog. **DELETE THIS ENTIRE FILE** when the real /listings API is wired in;
// the cart consumes a generic Product shape so the swap is a single-day refactor.
//
// 10 hand-picked meat products covering the categories we'll launch with. Prices are realistic per-kg figures for the
// Uzbek market (so'm). Each product carries an Uzbek + Russian name so the active locale flips them without an ARB
// entry per product (overkill for fake data).
//
// Images: Material icons over a tinted background — keeps the prototype offline-safe and avoids flaky network image
// loading during emulator/live-testing sessions. Real listings will use Image.network of the supplier-uploaded photos.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// One catalog entry. The fields here intentionally mirror what a real /listings API row will give us — id, names,
/// price, an image-or-icon placeholder — so the CartItem class doesn't have to change when we drop fakes.
class FakeProduct {
  final int id;
  final String nameUz;
  final String nameRu;
  final int priceSoum;   // price PER KG, in Uzbek so'm — display formatted with thousands separators
  final IconData icon;   // Material icon as offline-safe stand-in for the product photo
  final int accentArgb;  // background tint behind the icon — gives each tile distinct visual identity

  const FakeProduct({required this.id, required this.nameUz, required this.nameRu, required this.priceSoum,
                     required this.icon, required this.accentArgb});

  /// Return the display name for the active locale code. Falls back to Uzbek for any non-RU language
  /// (English is no longer a user-selectable option after the v3 pivot).
  String displayName(String languageCode) => languageCode == 'ru' ? nameRu : nameUz;
}


/// The ten products users see on the Menyu (home) screen. Order here drives the grid order. Kept compile-time const so
/// hot-reload and tests both pick up changes deterministically.
const fakeProducts = <FakeProduct>[
  FakeProduct(id: 1, nameUz: "Mol go'shti (premium)", nameRu: 'Говядина (премиум)',
              priceSoum: 95000, icon: Icons.kebab_dining_outlined, accentArgb: 0xFFFFE0E0),
  FakeProduct(id: 2, nameUz: "Qo'y go'shti (yangi)", nameRu: 'Баранина (свежая)',
              priceSoum: 110000, icon: Icons.outdoor_grill_outlined, accentArgb: 0xFFFFE8D5),
  FakeProduct(id: 3, nameUz: 'Tovuq (butun)', nameRu: 'Курица (целая)',
              priceSoum: 38000, icon: Icons.egg_alt_outlined, accentArgb: 0xFFFFF5D5),
  FakeProduct(id: 4, nameUz: 'Tovuq filesi', nameRu: 'Куриное филе',
              priceSoum: 48000, icon: Icons.set_meal_outlined, accentArgb: 0xFFE8F5E9),
  FakeProduct(id: 5, nameUz: "Echki go'shti", nameRu: 'Козлятина',
              priceSoum: 105000, icon: Icons.pets_outlined, accentArgb: 0xFFE3F2FD),
  FakeProduct(id: 6, nameUz: 'Mol jigari', nameRu: 'Говяжья печень',
              priceSoum: 55000, icon: Icons.local_dining_outlined, accentArgb: 0xFFF3E5F5),
  FakeProduct(id: 7, nameUz: "Mol qovurg'asi", nameRu: 'Говяжьи рёбра',
              priceSoum: 80000, icon: Icons.restaurant_outlined, accentArgb: 0xFFFFEBEE),
  FakeProduct(id: 8, nameUz: 'Qiyma (mol)', nameRu: 'Фарш (говяжий)',
              priceSoum: 75000, icon: Icons.lunch_dining_outlined, accentArgb: 0xFFFFF3E0),
  FakeProduct(id: 9, nameUz: 'Burger qiymasi', nameRu: 'Фарш для бургера',
              priceSoum: 70000, icon: Icons.fastfood_outlined, accentArgb: 0xFFFCE4EC),
  FakeProduct(id: 10, nameUz: 'Qazi (ot)', nameRu: 'Конская казы',
               priceSoum: 145000, icon: Icons.dining_outlined, accentArgb: 0xFFEFEBE9),
];


/// Riverpod handle for the catalog. Returning a `List<FakeProduct>` (not a stream) is fine — the data is compile-time
/// constant. When the real API lands, this provider is replaced by `listingsFeedProvider` and call sites stay the same.
final fakeProductsProvider = Provider<List<FakeProduct>>((ref) => fakeProducts);
