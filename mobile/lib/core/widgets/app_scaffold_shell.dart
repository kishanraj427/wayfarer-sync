import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/appMotion.dart';
import '../constants/appStrings.dart';
import '../motion/motion.dart';
import '../theme/appSemanticColors.dart';
import '../../features/tracking/widgets/locationAccessWatcher.dart';

class AppScaffoldShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffoldShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Wraps every signed-in screen, so "location is off" is noticed on app
    // open and on resume — not only on the map, which the user may never open.
    return LocationAccessWatcher(
      child: Scaffold(
      body: motionEnabled(context)
          ? PageTransitionSwitcher(
              duration: AppMotion.base,
              transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
                  FadeThroughTransition(
                animation: primaryAnimation,
                secondaryAnimation: secondaryAnimation,
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(navigationShell.currentIndex),
                child: navigationShell,
              ),
            )
          : navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        indicatorColor: context.semantic.activeContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff),
            label: AppStrings.navTrips,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: AppStrings.navProfile,
          ),
        ],
      ),
      ),
    );
  }
}
