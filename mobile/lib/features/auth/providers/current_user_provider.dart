import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/apiClient.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/authTokenProvider.dart';
import '../models/current_user.dart';

final currentUserProvider = FutureProvider<CurrentUser?>((ref) async {
  // Watch the token first so logout (token → null) recomputes this to null
  // instead of serving a stale cached identity.
  final token = ref.watch(authTokenProvider);
  if (token == null) {
    return null;
  }

  final prefs = await SharedPreferences.getInstance();
  final cachedUserJson = prefs.getString(AuthTokenNotifier.currentUserPrefsKey);
  if (cachedUserJson != null) {
    return CurrentUser.fromJson(jsonDecode(cachedUserJson) as Map<String, dynamic>);
  }

  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiUrl.me) as Map<String, dynamic>;
  final userJson = response['user'] as Map<String, dynamic>;
  await prefs.setString(AuthTokenNotifier.currentUserPrefsKey, jsonEncode(userJson));

  return CurrentUser.fromJson(userJson);
});

Future<void> persistCurrentUser(WidgetRef ref, Map<String, dynamic> userJson) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AuthTokenNotifier.currentUserPrefsKey, jsonEncode(userJson));
  ref.invalidate(currentUserProvider);
}
