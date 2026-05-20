// Riverpod wiring for the location service.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';


final locationServiceProvider = Provider<LocationService>((ref) => LocationService());


/// One-shot FutureProvider for the onboarding gate. True when the user has either granted permission OR
/// explicitly skipped — both flows mark onboarding done. Router consumes this to decide first-run routing.
final onboardingDoneProvider = FutureProvider<bool>((ref) async =>
    ref.watch(locationServiceProvider).onboardingDone());
