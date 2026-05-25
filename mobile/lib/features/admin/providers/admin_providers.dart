// Riverpod providers for the in-app admin page.
//
// Critical wiring: adminRepositoryProvider depends on AdminApiClient (via adminApiClientProvider, declared
// in admin_auth_providers.dart). That gives every admin call its own JWT pool — completely separate from
// the main app's authNotifier session.
//
// Pattern:
//   • adminRepositoryProvider — uses AdminApiClient (separate from main ApiClient)
//   • adminSuppliersProvider / adminCategoriesProvider / adminMarketsProvider — autoDispose FutureProviders
//     so leaving the /admin page drops the cache (admin page is opened rarely; freshness > prefetch).
//
// Mutations go through AdminRepository directly; after a successful write the caller invalidates the matching
// provider so the next read pulls fresh state. No optimistic UI here — the admin path is low-frequency and
// surface area for bugs (wrong supplier got a listing) far outweighs the latency win.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/supplier_profile.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_auth_providers.dart';


final adminRepositoryProvider = Provider<AdminRepository>(
    (ref) => AdminRepository(ref.watch(adminApiClientProvider)));


final adminSuppliersProvider = FutureProvider.autoDispose<List<SupplierProfile>>(
    (ref) => ref.watch(adminRepositoryProvider).listSuppliers());


final adminCategoriesProvider = FutureProvider.autoDispose<List<AdminCategory>>(
    (ref) => ref.watch(adminRepositoryProvider).listCategories());


final adminMarketsProvider = FutureProvider.autoDispose<List<AdminMarket>>(
    (ref) => ref.watch(adminRepositoryProvider).listMarkets());
