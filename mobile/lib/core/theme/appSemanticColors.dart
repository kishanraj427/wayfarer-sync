import 'package:flutter/material.dart';
import 'appTokens.dart';

/// Brand/semantic colors not covered by [ColorScheme]. Widgets read these via
/// `context.semantic.<name>` so every value adapts automatically between the
/// light and dark themes. Never reference [AppPalette] directly from a widget.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color route;
  final Color routeSubtle;
  final Color onRoute;
  final Color signalOnline;
  final Color signalPending;
  final Color hairline;
  final Color glassFill;
  final Color glassStroke;
  final Color contour;
  final Color selfMarker;
  final Color destinationPin;
  final Color peerFallback;
  final Color onMarker;
  final Color activeContainer;
  final Color onActiveContainer;
  final Color endedContainer;
  final Color statValue;

  const AppSemanticColors({
    required this.route,
    required this.routeSubtle,
    required this.onRoute,
    required this.signalOnline,
    required this.signalPending,
    required this.hairline,
    required this.glassFill,
    required this.glassStroke,
    required this.contour,
    required this.selfMarker,
    required this.destinationPin,
    required this.peerFallback,
    required this.onMarker,
    required this.activeContainer,
    required this.onActiveContainer,
    required this.endedContainer,
    required this.statValue,
  });

  static const light = AppSemanticColors(
    route: AppPalette.accent,
    routeSubtle: AppPalette.accentSubtleLight,
    onRoute: AppPalette.onAccent,
    signalOnline: AppPalette.green,
    signalPending: AppPalette.blue,
    hairline: AppPalette.hairline,
    glassFill: AppPalette.glassFillLight,
    glassStroke: AppPalette.hairline,
    contour: AppPalette.contourLight,
    selfMarker: AppPalette.accent,
    destinationPin: AppPalette.accent,
    peerFallback: AppPalette.blue,
    onMarker: AppPalette.onAccent,
    activeContainer: AppPalette.greenContainer,
    onActiveContainer: AppPalette.onGreenContainer,
    endedContainer: AppPalette.endedContainer,
    statValue: AppPalette.rust,
  );

  static const dark = AppSemanticColors(
    route: AppPalette.accentDark,
    routeSubtle: AppPalette.accentSubtleDark,
    onRoute: AppPalette.onAccentDark,
    signalOnline: AppPalette.greenDark,
    signalPending: AppPalette.blueDark,
    hairline: AppPalette.hairlineDark,
    glassFill: AppPalette.glassFillDark,
    glassStroke: AppPalette.hairlineDark,
    contour: AppPalette.contourDark,
    selfMarker: AppPalette.accentDark,
    destinationPin: AppPalette.accentDark,
    peerFallback: AppPalette.blueDark,
    onMarker: AppPalette.onAccentDark,
    activeContainer: AppPalette.greenContainerDark,
    onActiveContainer: AppPalette.onGreenContainerDark,
    endedContainer: AppPalette.endedContainerDark,
    statValue: AppPalette.rustDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? route,
    Color? routeSubtle,
    Color? onRoute,
    Color? signalOnline,
    Color? signalPending,
    Color? hairline,
    Color? glassFill,
    Color? glassStroke,
    Color? contour,
    Color? selfMarker,
    Color? destinationPin,
    Color? peerFallback,
    Color? onMarker,
    Color? activeContainer,
    Color? onActiveContainer,
    Color? endedContainer,
    Color? statValue,
  }) {
    return AppSemanticColors(
      route: route ?? this.route,
      routeSubtle: routeSubtle ?? this.routeSubtle,
      onRoute: onRoute ?? this.onRoute,
      signalOnline: signalOnline ?? this.signalOnline,
      signalPending: signalPending ?? this.signalPending,
      hairline: hairline ?? this.hairline,
      glassFill: glassFill ?? this.glassFill,
      glassStroke: glassStroke ?? this.glassStroke,
      contour: contour ?? this.contour,
      selfMarker: selfMarker ?? this.selfMarker,
      destinationPin: destinationPin ?? this.destinationPin,
      peerFallback: peerFallback ?? this.peerFallback,
      onMarker: onMarker ?? this.onMarker,
      activeContainer: activeContainer ?? this.activeContainer,
      onActiveContainer: onActiveContainer ?? this.onActiveContainer,
      endedContainer: endedContainer ?? this.endedContainer,
      statValue: statValue ?? this.statValue,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      route: Color.lerp(route, other.route, t)!,
      routeSubtle: Color.lerp(routeSubtle, other.routeSubtle, t)!,
      onRoute: Color.lerp(onRoute, other.onRoute, t)!,
      signalOnline: Color.lerp(signalOnline, other.signalOnline, t)!,
      signalPending: Color.lerp(signalPending, other.signalPending, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassStroke: Color.lerp(glassStroke, other.glassStroke, t)!,
      contour: Color.lerp(contour, other.contour, t)!,
      selfMarker: Color.lerp(selfMarker, other.selfMarker, t)!,
      destinationPin: Color.lerp(destinationPin, other.destinationPin, t)!,
      peerFallback: Color.lerp(peerFallback, other.peerFallback, t)!,
      onMarker: Color.lerp(onMarker, other.onMarker, t)!,
      activeContainer: Color.lerp(activeContainer, other.activeContainer, t)!,
      onActiveContainer:
          Color.lerp(onActiveContainer, other.onActiveContainer, t)!,
      endedContainer: Color.lerp(endedContainer, other.endedContainer, t)!,
      statValue: Color.lerp(statValue, other.statValue, t)!,
    );
  }
}

/// Ergonomic accessor so widgets can write `context.semantic.route`.
extension SemanticColorsX on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
