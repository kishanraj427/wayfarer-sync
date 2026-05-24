import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Manage user JWT token state in memory.
/// (In production, replace this with flutter_secure_storage for encryption)
class AuthTokenNotifier extends StateNotifier<String?> {
  AuthTokenNotifier() : super(null);

  void setToken(String token) => state = token;
  void clearToken() => state = null;

  bool get isAuthenticated => state != null;
}

final authTokenProvider = StateNotifierProvider<AuthTokenNotifier, String?>((
  ref,
) {
  return AuthTokenNotifier();
});
