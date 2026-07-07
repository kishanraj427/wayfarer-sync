import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/appMotion.dart';

/// True when the OS is NOT requesting reduced motion.
bool motionEnabled(BuildContext context) =>
    !MediaQuery.of(context).disableAnimations;

extension AppEntrance on Widget {
  /// Standard staggered entrance: fade + small upward slide.
  /// Returns the widget unchanged when reduced motion is active, so callers
  /// never need to branch themselves.
  Widget appEntrance(BuildContext context, {int index = 0}) {
    if (!motionEnabled(context)) return this;
    final steps = math.min(index, AppMotion.maxStaggerItems);
    return animate(delay: AppMotion.staggerStep * steps)
        .fadeIn(duration: AppMotion.base, curve: AppMotion.curveStandard)
        .slideY(
          begin: AppMotion.slideOffset,
          end: 0,
          duration: AppMotion.base,
          curve: AppMotion.curveStandard,
        );
  }

  /// Scale + fade "pop-in", suited to map markers and small emphasis moments.
  /// Returns the widget unchanged when reduced motion is active.
  Widget appPopIn(BuildContext context) {
    if (!motionEnabled(context)) return this;
    return animate()
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
          duration: AppMotion.fast,
          curve: AppMotion.curveStandard,
        )
        .fadeIn(duration: AppMotion.fast);
  }
}
