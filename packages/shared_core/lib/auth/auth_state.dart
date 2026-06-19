import '../models/user.dart';

/// Sealed auth state shared between buyer + partner apps.
///
/// Switch-exhaustive so adding a new variant forces every consumer to handle it. The buyer app's
/// AuthNotifier and the partner app's PartnerAuthNotifier both produce this type.
sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState { const AuthInitial(); }

final class AuthLoading extends AuthState { const AuthLoading(); }

/// User is signed in; consumer can read `user.role` to branch role-specific UI.
final class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}

/// Brand-new session OR explicit logout — no error to display.
final class AuthAnonymous extends AuthState { const AuthAnonymous(); }

/// Last-attempt failure — login screens render `message` inline.
final class AuthUnauthenticated extends AuthState {
  final String? message;
  const AuthUnauthenticated([this.message]);
}
