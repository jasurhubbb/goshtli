// AuthState — sealed class powering the AuthNotifier. Switch-exhaustive so adding a new variant forces every consumer to handle it.
import '../../../shared/models/user.dart';


sealed class AuthState {
  const AuthState();
}


/// Initial state at app start — shown while we resume from secure storage and call /me.
final class AuthInitial extends AuthState {
  const AuthInitial();
}


/// Spinner state used during login/register/refresh — UI disables submit buttons here.
final class AuthLoading extends AuthState {
  const AuthLoading();
}


/// User has a valid token and a loaded profile — UI swaps in the role-based home.
final class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}


/// No session (or session expired). Optional error message renders on the login screen.
final class AuthUnauthenticated extends AuthState {
  final String? error;
  const AuthUnauthenticated([this.error]);
}
