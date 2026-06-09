import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/authTokenProvider.dart';
import 'core/network/router.dart';
import 'features/tracking/providers/connectivityProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  String? token;
  try {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(AuthTokenNotifier.tokenKey);
  } catch (e) {
    // ignore: avoid_print
    print('Error loading initial auth token: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        authTokenProvider.overrideWith((ref) => AuthTokenNotifier(token)),
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

    return MaterialApp.router(
      title: 'Wayfarer Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3388FF),
          brightness: Brightness.light,
        ),
      ),
      routerConfig: router,
    );
  }
}
