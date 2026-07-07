import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/appRoutes.dart';
import '../constants/appStrings.dart';
import '../network/authTokenProvider.dart';
import '../widgets/app_scaffold_shell.dart';
import '../../features/tracking/screens/trip_map_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/trip/screens/trips_screen.dart';
import '../../features/trip/screens/create_trip_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

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
    initialLocation: AppRoutes.login,
    refreshListenable: listenable,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = ref.read(authTokenProvider) != null;
      final loggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;

      if (!isAuthenticated) {
        return loggingIn ? null : AppRoutes.login;
      }

      if (loggingIn) {
        return AppRoutes.trips;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _transitionPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.signup,
        pageBuilder: (context, state) => _transitionPage(state, const SignupScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppScaffoldShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.trips, builder: (context, state) => const TripsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.createTrip,
        pageBuilder: (context, state) => _transitionPage(state, const CreateTripScreen()),
      ),
      GoRoute(
        path: AppRoutes.tripMapPattern,
        pageBuilder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          final userId = state.pathParameters['userId']!;
          final tripTitle = (state.extra as String?) ?? AppStrings.liveTripFallback;
          return _transitionPage(
            state,
            TripMapScreen(
              tripId: tripId,
              tripTitle: tripTitle,
              currentUserId: userId,
            ),
          );
        },
      ),
    ],
  );
});
