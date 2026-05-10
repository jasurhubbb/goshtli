// Riverpod providers for reviews — repo + per-supplier list + per-supplier aggregate (cached separately so the
// avg-stars on listing cards doesn't refetch the full list when the cards repaint).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/paginated.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/reviews_repository.dart';


final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) =>
    ReviewsRepository(ref.watch(apiClientProvider)));


/// All reviews for a supplier — used by the supplier-reviews screen + listing detail "X reviews" section.
final supplierReviewsProvider = FutureProvider.autoDispose
    .family<Paginated<Review>, int>((ref, supplierId) async =>
        ref.watch(reviewsRepositoryProvider).listForSupplier(supplierId));


/// Lightweight (avg, count) for a supplier — used for the ★ rating on every card.
/// Cached longer-lived than the full list so card scroll doesn't refetch repeatedly.
final supplierRatingProvider = FutureProvider
    .family<SupplierRating, int>((ref, supplierId) async =>
        ref.watch(reviewsRepositoryProvider).aggregateForSupplier(supplierId));
