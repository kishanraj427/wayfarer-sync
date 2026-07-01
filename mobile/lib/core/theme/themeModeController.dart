import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app theme mode. Default is light; a future release can switch the
/// default or expose a settings toggle by calling [ThemeModeNotifier.setMode]
/// with no changes to any screen.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initialMode);

  static const prefsKey = 'theme_mode';

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, mode.name);
  }
}

/// Resolves a persisted string back into a [ThemeMode], defaulting to light.
ThemeMode themeModeFromString(String? value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.light;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ThemeMode.light);
});
