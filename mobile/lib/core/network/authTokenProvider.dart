import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenNotifier extends StateNotifier<String?> {
  // ignore: use_super_parameters
  AuthTokenNotifier(String? initialToken) : super(initialToken);

  static const tokenKey = 'jwt_token';

  Future<void> setToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      state = token;
    } catch (e) {
      // ignore: avoid_print
      print('Error saving auth token: $e');
    }
  }

  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      state = null;
    } catch (e) {
      // ignore: avoid_print
      print('Error clearing auth token: $e');
    }
  }

  bool get isAuthenticated => state != null;
}

final authTokenProvider = StateNotifierProvider<AuthTokenNotifier, String?>((ref) {
  return AuthTokenNotifier(null);
});

final currentUserIdProvider = Provider<String?>((ref) {
  final token = ref.watch(authTokenProvider);
  if (token == null) return null;
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var normalized = base64Url.normalize(parts[1]);
    final payloadString = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(payloadString) as Map<String, dynamic>;
    return payload['userId'] as String?;
  } catch (e) {
    return null;
  }
});
