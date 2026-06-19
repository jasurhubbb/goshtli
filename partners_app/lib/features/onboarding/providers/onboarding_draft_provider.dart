import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../onboarding_draft.dart';

/// Holds the wizard draft + current step. Persists draft to SP so backgrounding doesn't lose work.
class OnboardingDraftNotifier extends StateNotifier<OnboardingDraft> {
  OnboardingDraftNotifier() : super(const OnboardingDraft()) { _load(); }

  static const _kKey = 'onboarding_draft';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw != null) {
      try {
        state = OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, jsonEncode(state.toJson()));
  }

  void update(OnboardingDraft Function(OnboardingDraft) updater) {
    state = updater(state);
    _persist();
  }

  Future<void> clear() async {
    state = const OnboardingDraft();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}


final onboardingDraftProvider = StateNotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
    (ref) => OnboardingDraftNotifier());

final onboardingStepProvider = StateProvider<int>((ref) => 0);
