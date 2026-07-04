import 'package:flutter/material.dart';

/// Raw palette. The ONLY place literal colors live; consumed exclusively by the
/// theme builders and the semantic color extension.
abstract final class AppPalette {
  // Light
  static const accent = Color(0xFFFF5722);
  static const onAccent = Color(0xFFFFFFFF);
  static const rust = Color(0xFFB02F00);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF5B4039);
  static const hairline = Color(0xFFE4BEB4);
  static const green = Color(0xFF1B6D24);
  static const greenContainer = Color(0xFFA0F399);
  static const onGreenContainer = Color(0xFF217128);
  static const blue = Color(0xFF005CAB);
  static const blueContainer = Color(0xFF1775D1);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const endedContainer = Color(0xFFE1E3E4);
  static const glassFillLight = Color(0xCCFFFFFF);
  static const contourLight = Color(0x14191C1D);
  static const accentSubtleLight = Color(0x1AFF5722);

  // Dark (derived from the same roles)
  static const accentDark = Color(0xFFFF8A65);
  static const onAccentDark = Color(0xFF591C00);
  static const rustDark = Color(0xFFFFB5A0);
  static const backgroundDark = Color(0xFF1A1110);
  static const surfaceDark = Color(0xFF241A18);
  static const onSurfaceDark = Color(0xFFF0E0DB);
  static const onSurfaceVariantDark = Color(0xFFD8C2BA);
  static const hairlineDark = Color(0xFF3A2C28);
  static const greenDark = Color(0xFF88D982);
  static const greenContainerDark = Color(0xFF005312);
  static const onGreenContainerDark = Color(0xFFA3F69C);
  static const blueDark = Color(0xFFA5C8FF);
  static const blueContainerDark = Color(0xFF004786);
  static const errorDark = Color(0xFFFFB4AB);
  static const errorContainerDark = Color(0xFF93000A);
  static const endedContainerDark = Color(0xFF3A2C28);
  static const glassFillDark = Color(0xCC241A18);
  static const contourDark = Color(0x1AF0E0DB);
  static const accentSubtleDark = Color(0x24FF8A65);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 20.0;
}
