import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/appStrings.dart';
import 'core/network/authTokenProvider.dart';
import 'core/router/router.dart';
import 'core/theme/appTheme.dart';
import 'core/theme/themeModeController.dart';
import 'features/tracking/providers/connectivityProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  String? token;
  ThemeMode initialThemeMode = ThemeMode.light;
  try {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(AuthTokenNotifier.tokenKey);
    initialThemeMode = themeModeFromString(prefs.getString(ThemeModeNotifier.prefsKey));
  } catch (e) {
    // ignore: avoid_print
    print('Error loading initial preferences: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        authTokenProvider.overrideWith((ref) => AuthTokenNotifier(token)),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier(initialThemeMode)),
      ],
      child: const WayfarerSyncApp(),
    ),
  );
}

class WayfarerSyncApp extends ConsumerWidget {
  const WayfarerSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectivitySyncListenerProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
