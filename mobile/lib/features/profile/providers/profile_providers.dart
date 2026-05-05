// Profile providers — repository plus role-specific async providers. We don't union the two profile types because
// screens already know the user role from auth state and pick the right provider.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/buyer_profile.dart';
import '../../../shared/models/supplier_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/profile_repository.dart';


final profileRepositoryProvider = Provider<ProfileRepository>((ref) =>
    ProfileRepository(ref.watch(apiClientProvider)));


final myBuyerProfileProvider = FutureProvider.autoDispose<BuyerProfile>((ref) async =>
    ref.watch(profileRepositoryProvider).getBuyerProfile());


final mySupplierProfileProvider = FutureProvider.autoDispose<SupplierProfile>((ref) async =>
    ref.watch(profileRepositoryProvider).getSupplierProfile());
