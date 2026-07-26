import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/appMotion.dart';
import 'core/constants/appStrings.dart';
import 'core/network/authSession.dart';
import 'core/network/authTokenProvider.dart';
import 'core/network/refreshCoordinator.dart';
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

  Animate.defaultDuration = AppMotion.base;
  Animate.defaultCurve = AppMotion.curveStandard;

  String? accessToken;
  String? refreshToken;
  ThemeMode initialThemeMode = ThemeMode.light;
  try {
    final prefs = await SharedPreferences.getInstance();
    // accessTokenKey is unchanged from the previous release, so an in-place
    // upgrade stays logged in; refreshToken is absent until the first exchange.
    accessToken = prefs.getString(AuthSessionNotifier.accessTokenKey);
    refreshToken = prefs.getString(AuthSessionNotifier.refreshTokenKey);
    initialThemeMode = themeModeFromString(prefs.getString(ThemeModeNotifier.prefsKey));
  } catch (e) {
    // ignore: avoid_print
    print('Error loading initial preferences: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => AuthSessionNotifier(
            AuthSession(accessToken: accessToken, refreshToken: refreshToken),
          ),
        ),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier(initialThemeMode)),
      ],
      child: const WayfarerSyncApp(),
    ),
  );
}

class WayfarerSyncApp extends ConsumerStatefulWidget {
  const WayfarerSyncApp({super.key});

  @override
  ConsumerState<WayfarerSyncApp> createState() => _WayfarerSyncAppState();
}

class _WayfarerSyncAppState extends ConsumerState<WayfarerSyncApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Renew on resume so the first tap works instead of paying a 401 round-trip.
    _lifecycle = AppLifecycleListener(onResume: _renewCredentials);
  }

  void _renewCredentials() {
    final session = ref.read(authSessionProvider);
    if (!session.isAuthenticated) return;

    final coordinator = ref.read(refreshCoordinatorProvider);
    // Fire and forget. Every failure mode is retryLater and never logs
    // anyone out (R1), so there is nothing to await or handle here.
    if (session.needsExchange) {
      coordinator.exchange();
    } else {
      coordinator.refresh();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
