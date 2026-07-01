import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'authTokenProvider.dart';
import '../../features/tracking/screens/tripMapScreen.dart';
import '../../features/auth/screens/loginScreen.dart';
import '../../features/auth/screens/signupScreen.dart';
import '../../features/trip/screens/tripsScreen.dart';
import '../../features/trip/screens/createTripScreen.dart';

/// Wraps a screen in a shared-axis (horizontal) transition for smooth,
/// direction-aware navigation between routes.
CustomTransitionPage<void> _transitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        child: child,
      );
    },
  );
}


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
        pageBuilder: (context, state) => _transitionPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => _transitionPage(state, const SignupScreen()),
      ),
      GoRoute(
        path: '/trips',
        pageBuilder: (context, state) => _transitionPage(state, const TripsScreen()),
      ),
      GoRoute(
        path: '/create-trip',
        pageBuilder: (context, state) => _transitionPage(state, const CreateTripScreen()),
      ),
      GoRoute(
        path: '/trip/:tripId/map/:userId',
        pageBuilder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          final userId = state.pathParameters['userId']!;
          return _transitionPage(
            state,
            TripMapScreen(tripId: tripId, currentUserId: userId),
          );
        },
      ),
    ],
  );
});
