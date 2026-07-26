import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/apiClient.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/authTokenProvider.dart';
import '../models/current_user.dart';

final currentUserProvider = FutureProvider<CurrentUser?>((ref) async {
  // Watch the session first so logout recomputes this to null instead of
  // serving a stale cached identity.
  final session = ref.watch(authSessionProvider);
  if (!session.isAuthenticated) {
    return null;
  }

  final prefs = await SharedPreferences.getInstance();
  final cachedUserJson = prefs.getString(AuthSessionNotifier.currentUserPrefsKey);
  if (cachedUserJson != null) {
    // Defensive (L1): cached JSON may predate a model change, and a hard cast
    // here would brick startup for anyone holding an older cache.
    final decoded = jsonDecode(cachedUserJson);
    if (decoded is Map<String, dynamic>) {
      return CurrentUser.fromJson(decoded);
    }
  }

  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiUrl.me);
  if (response is! Map<String, dynamic>) return null;

  // Defensive (L1): never a non-nullable cast on a server-controlled field.
  final userJson = response[_userField];
  if (userJson is! Map<String, dynamic>) return null;

  await prefs.setString(
    AuthSessionNotifier.currentUserPrefsKey,
    jsonEncode(userJson),
  );

  return CurrentUser.fromJson(userJson);
});

const String _userField = 'user';

Future<void> persistCurrentUser(WidgetRef ref, Map<String, dynamic> userJson) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    AuthSessionNotifier.currentUserPrefsKey,
    jsonEncode(userJson),
  );
  ref.invalidate(currentUserProvider);
}
