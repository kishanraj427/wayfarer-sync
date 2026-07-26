import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/appConstants.dart';
import 'authSession.dart';
import 'jwtClaims.dart';

class AuthSessionNotifier extends StateNotifier<AuthSession> {
  AuthSessionNotifier(super.initial);

  static const accessTokenKey = AppConstants.jwtTokenKey;      // unchanged: upgrades in place
  static const refreshTokenKey = AppConstants.refreshTokenKey;
  static const currentUserPrefsKey = AppConstants.currentUserKey;

  /// Public read of the current session (`state` is `@protected`, so callers
  /// like `RefreshCoordinator` must go through this instead).
  AuthSession get session => state;

  LogoutReason? _pendingLogoutReason;

  Future<void> setTokens({required String accessToken, required String refreshToken}) async {
    state = AuthSession(accessToken: accessToken, refreshToken: refreshToken);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(accessTokenKey, accessToken);
      await prefs.setString(refreshTokenKey, refreshToken);
    } catch (_) {
      // State is already updated; a failed write only costs persistence
      // across a restart. Never surfaced as a logout (R1).
    }
  }

  Future<void> setAccessToken(String accessToken) async {
    state = state.copyWith(accessToken: accessToken);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(accessTokenKey, accessToken);
    } catch (_) {}
  }

  Future<void> clear({required LogoutReason reason}) async {
    _pendingLogoutReason = reason;
    state = AuthSession.empty;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(accessTokenKey);
      await prefs.remove(refreshTokenKey);
      await prefs.remove(currentUserPrefsKey);
    } catch (_) {}
  }

  /// Read once by the login screen to explain why the user is here (R4).
  LogoutReason? consumeLogoutReason() {
    final reason = _pendingLogoutReason;
    _pendingLogoutReason = null;
    return reason;
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession>((ref) {
  return AuthSessionNotifier(AuthSession.empty);
});

/// Kept for existing call sites. Reads userId from the access token payload —
/// works offline and even when the token has expired.
final currentUserIdProvider = Provider<String?>((ref) {
  final token = ref.watch(authSessionProvider).accessToken;
  return token == null ? null : userIdFromToken(token);
});
