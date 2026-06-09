import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'authTokenProvider.dart';
import '../../features/tracking/screens/tripMapScreen.dart';
import '../../features/auth/screens/loginScreen.dart';
import '../../features/auth/screens/signupScreen.dart';
import '../../features/trip/screens/tripsScreen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  // Create a ValueNotifier to act as the refreshListenable for GoRouter
  final listenable = ValueNotifier<String?>(ref.read(authTokenProvider));
  
  // Listen to token changes to notify GoRouter of updates.
  // Using ref.listen avoids rebuilding routerProvider itself, keeping GoRouter instance stable.
  ref.listen<String?>(authTokenProvider, (previous, next) {
    listenable.value = next;
  });
  
  // Dispose the ValueNotifier when the provider is destroyed
  ref.onDispose(() {
    listenable.dispose();
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: listenable,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = ref.read(authTokenProvider) != null;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (!isAuthenticated) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
        return '/trips';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripsScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/map/:userId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          final userId = state.pathParameters['userId']!;
          return TripMapScreen(tripId: tripId, currentUserId: userId);
        },
      ),
    ],
  );
});
