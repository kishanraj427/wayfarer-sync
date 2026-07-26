/// Why a session ended — surfaced on the login screen so a forced sign-out is
/// never unexplained (R4).
enum LogoutReason { userInitiated, sessionExpired }

/// Result of a refresh attempt. Only [sessionDead] ends a session (R1).
enum RefreshOutcome {
  success,

  /// Transient failure — network, timeout, 5xx. Session is KEPT.
  retryLater,

  /// The server explicitly rejected the refresh token. Session is CLEARED.
  sessionDead,

  /// An access token exists with no refresh token: an in-place upgrade from
  /// v1.0.4+5. Must run /auth/exchange, NOT log the user out.
  needsExchange,
}

class AuthSession {
  final String? accessToken;
  final String? refreshToken;

  const AuthSession({this.accessToken, this.refreshToken});

  static const AuthSession empty = AuthSession();

  /// Deliberately NOT "is the access token valid". An expired access token
  /// with no network is normal for an offline-first app; the router must still
  /// admit the user so GPS keeps recording (R1).
  bool get isAuthenticated => accessToken != null || refreshToken != null;

  /// True for installs upgraded in place from a version without refresh tokens.
  bool get needsExchange => refreshToken == null && accessToken != null;

  AuthSession copyWith({String? accessToken, String? refreshToken}) => AuthSession(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
      );
}
