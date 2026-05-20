// AuthState — sealed class powering the AuthNotifier. Switch-exhaustive so adding a new variant forces every consumer to handle it.
//
// v3 pivot: app boots anonymous by default. Users can browse listings/search/etc. without an account; auth is only
// prompted when they try to do something that needs it (place order, favorite, chat, view profile/orders).
import '../../../shared/models/user.dart';


sealed class AuthState {
  const AuthState();
}


/// Initial state at app start — shown briefly while we read storage. Routing waits for this to resolve.
final class AuthInitial extends AuthState {
  const AuthInitial();
}


/// Spinner state used during login/register/refresh — UI disables submit buttons here.
final class AuthLoading extends AuthState {
  const AuthLoading();
}


/// User has a valid token and a loaded profile.
final class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}


/// User is browsing without an account. Public routes work; auth-required actions trigger a sign-in sheet.
/// This is the DEFAULT state for fresh installs — not an error.
final class AuthAnonymous extends AuthState {
  const AuthAnonymous();
}


/// Session expired or refresh failed — distinguishes "your previous session is gone" from a first-time anonymous user.
/// Renders an info message on the login screen.
final class AuthUnauthenticated extends AuthState {
  final String? error;
  const AuthUnauthenticated([this.error]);
}
