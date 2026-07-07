import 'package:flutter/animation.dart';

/// Central motion tokens: durations, curve, and offsets for app-wide
/// animation. Mirrors the AppStrings / AppConstants / AppRoutes convention.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);

  /// Delay added per list item for staggered entrances.
  static const Duration staggerStep = Duration(milliseconds: 40);

  static const Curve curveStandard = Curves.easeOutCubic;

  /// Fraction of a widget's height used for the entrance slide.
  static const double slideOffset = 0.08;

  /// Cap on the stagger index so long lists don't lag at the tail.
  static const int maxStaggerItems = 12;
}
