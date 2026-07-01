import 'package:flutter/material.dart';

/// Raw palette. This is the ONLY place literal colors live; they are consumed
/// exclusively by the theme builders and the semantic color extension.
abstract final class AppPalette {
  // Light
  static const ink900 = Color(0xFF0C1B2A);
  static const slate500 = Color(0xFF5B6B7B);
  static const mist50 = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFE3E8EF);
  static const route500 = Color(0xFFFF6A3D);
  static const signalGreen = Color(0xFF2FB27C);
  static const amber = Color(0xFFF5A524);
  static const onRouteLight = Color(0xFFFFFFFF);
  static const glassFillLight = Color(0xCCFFFFFF);
  static const contourLight = Color(0x140C1B2A);
  static const routeSubtleLight = Color(0x1AFF6A3D);

  // Dark
  static const inkBgDark = Color(0xFF0B1622);
  static const surfaceDark = Color(0xFF14202E);
  static const hairlineDark = Color(0xFF24323F);
  static const textHiDark = Color(0xFFE6ECF3);
  static const textLoDark = Color(0xFF9AAABB);
  static const route500Dark = Color(0xFFFF7A50);
  static const signalGreenDark = Color(0xFF35C088);
  static const amberDark = Color(0xFFF5B33F);
  static const onRouteDark = Color(0xFF15202B);
  static const glassFillDark = Color(0xCC14202E);
  static const contourDark = Color(0x1AE6ECF3);
  static const routeSubtleDark = Color(0x24FF7A50);
}

/// Spacing scale (mode-independent).
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Corner-radius scale (mode-independent).
abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
}
