import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show apiClientProvider;
import '../data/qassob_models.dart';
import '../data/qassob_repository.dart';


final qassobRepositoryProvider = Provider<QassobRepository>((ref) =>
    QassobRepository(ref.watch(apiClientProvider)));


/// Animal filter on the Servislar tab. Empty string = no filter (Hammasi chip).
final servicesAnimalFilterProvider = StateProvider<String>((ref) => '');


/// Section A — qassobs (any). Section B — qushxona xizmatlari (slaughterhouses).
final qassobsListProvider = FutureProvider<List<Qassob>>((ref) async {
  return ref.watch(qassobRepositoryProvider).list(
    animal: ref.watch(servicesAnimalFilterProvider));
});


final slaughterhouseListProvider = FutureProvider<List<Qassob>>((ref) async {
  return ref.watch(qassobRepositoryProvider).list(
    animal: ref.watch(servicesAnimalFilterProvider), service: 'slaughter');
});
