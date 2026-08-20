import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meat_marketplace/features/listings/presentation/listing_detail_screen.dart';
import 'package:meat_marketplace/features/listings/providers/listings_providers.dart';
import 'package:meat_marketplace/shared/models/listing.dart';

const _listing = Listing(
  id: 7,
  slug: 'beef-cuts',
  market: MarketSummary(
    id: 9,
    slug: 'hidden-owner',
    nameUz: 'Hidden Supplier Market',
    nameRu: 'Hidden Supplier Market RU',
    region: 'Hidden Supplier Region',
    logoUrl: '',
    isActive: true,
  ),
  category: MeatCategorySummary(
    slug: 'beef',
    nameUz: "Mol go'shti",
    nameRu: 'Говядина',
    imageUrl: '',
  ),
  nameUz: "Mol go'shti bo'laklari",
  nameRu: 'Куски говядины',
  descriptionUz: 'Yangi mahsulot',
  descriptionRu: 'Свежий продукт',
  quantityKg: 100,
  pricePerKg: 95000,
  location: 'Toshkent',
  availableFrom: '2026-08-03',
  status: ListingStatus.active,
  photos: [],
);

void main() {
  testWidgets('product detail does not expose supplier or market identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listingByIdProvider.overrideWith((ref, id) async => _listing),
        ],
        child: const MaterialApp(home: ListingDetailScreen(listingId: 7)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Mol go'shti bo'laklari"), findsOneWidget);
    expect(find.text('Yangi mahsulot'), findsOneWidget);
    expect(find.textContaining('Hidden Supplier'), findsNothing);
    expect(find.text('Sotuvchi haqida'), findsNothing);
  });
}
