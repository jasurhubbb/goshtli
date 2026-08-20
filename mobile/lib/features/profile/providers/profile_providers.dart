// Buyer profile providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/buyer_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final myBuyerProfileProvider = FutureProvider.autoDispose<BuyerProfile>(
  (ref) async => ref.watch(profileRepositoryProvider).getBuyerProfile(),
);
