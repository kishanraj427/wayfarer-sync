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
  });

  static const light = AppSemanticColors(
    route: AppPalette.route500,
    routeSubtle: AppPalette.routeSubtleLight,
    onRoute: AppPalette.onRouteLight,
    signalOnline: AppPalette.signalGreen,
    signalPending: AppPalette.amber,
    hairline: AppPalette.hairline,
    glassFill: AppPalette.glassFillLight,
    glassStroke: AppPalette.hairline,
    contour: AppPalette.contourLight,
    selfMarker: AppPalette.route500,
    destinationPin: AppPalette.signalGreen,
    peerFallback: AppPalette.ink900,
    onMarker: AppPalette.onRouteLight,
  );

  static const dark = AppSemanticColors(
    route: AppPalette.route500Dark,
    routeSubtle: AppPalette.routeSubtleDark,
    onRoute: AppPalette.onRouteDark,
    signalOnline: AppPalette.signalGreenDark,
    signalPending: AppPalette.amberDark,
    hairline: AppPalette.hairlineDark,
    glassFill: AppPalette.glassFillDark,
    glassStroke: AppPalette.hairlineDark,
    contour: AppPalette.contourDark,
    selfMarker: AppPalette.route500Dark,
    destinationPin: AppPalette.signalGreenDark,
    peerFallback: AppPalette.textHiDark,
    onMarker: AppPalette.onRouteLight,
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
    );
  }
}

/// Ergonomic accessor so widgets can write `context.semantic.route`.
extension SemanticColorsX on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
