// PendingRedirect — a tiny state-holder for "where to go after the user finishes logging in".
//
// Why it exists: when an anonymous buyer taps "Proceed to payment" on the delivery page, we want to
// route them to the phone-login flow AND drop them back on /delivery (with their cart + selections
// intact) after they sign in. Without this provider the login flow always lands the user on /,
// dropping the in-progress checkout.
//
// Set from the gate (delivery/order screens) BEFORE pushing /auth/phone. Read + cleared from the auth
// notifier after a successful login/registration. Profile-tab logins skip this entirely (they never
// set the pending redirect, so post-login routing falls back to "/" as before).
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// Holds the pathname (e.g. "/delivery") to redirect to after the next successful authentication, or
/// null when there's no pending redirect (the common case — profile-tab logins, app-launch resumes).
class PendingRedirectNotifier extends StateNotifier<String?> {
  PendingRedirectNotifier() : super(null);

  /// Stash a destination before sending the user to the auth screens.
  void set(String path) => state = path;

  /// Consume the pending redirect — returns the path AND clears it in one shot so the auth notifier's
  /// post-login routing can hand off to GoRouter without leaving stale state behind for the next visit.
  String? take() {
    final v = state;
    state = null;
    return v;
  }

  void clear() => state = null;
}


final pendingRedirectProvider =
    StateNotifierProvider<PendingRedirectNotifier, String?>((ref) => PendingRedirectNotifier());
