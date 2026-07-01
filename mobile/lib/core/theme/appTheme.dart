import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'appSemanticColors.dart';
import 'appTokens.dart';

/// Light + dark themes share one builder so the two stay in lockstep. Ship
/// light by default; switching to dark is a [ThemeMode] change, no screen edits.
ThemeData buildLightTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final semantic = isDark ? AppSemanticColors.dark : AppSemanticColors.light;

  final background = isDark ? AppPalette.inkBgDark : AppPalette.mist50;
  final surface = isDark ? AppPalette.surfaceDark : AppPalette.surface;
  final textHi = isDark ? AppPalette.textHiDark : AppPalette.ink900;
  final textLo = isDark ? AppPalette.textLoDark : AppPalette.slate500;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: semantic.route,
    brightness: brightness,
  ).copyWith(
    surface: surface,
    onSurface: textHi,
    onSurfaceVariant: textLo,
    primary: semantic.route,
    onPrimary: semantic.onRoute,
    outline: semantic.hairline,
  );

  TextStyle display(double size, FontWeight weight) =>
      GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: weight, color: textHi);
  TextStyle body(double size, FontWeight weight, Color color) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color);

  final textTheme = TextTheme(
    displaySmall: display(32, FontWeight.w700),
    headlineSmall: display(24, FontWeight.w700),
    titleLarge: display(20, FontWeight.w600),
    titleMedium: body(16, FontWeight.w600, textHi),
    bodyLarge: body(15, FontWeight.w400, textHi),
    bodyMedium: body(14, FontWeight.w400, textLo),
    labelLarge: body(14, FontWeight.w600, textHi),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    textTheme: textTheme,
    extensions: [semantic],
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textHi,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: display(20, FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: semantic.hairline),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: semantic.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: semantic.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: semantic.route, width: 1.6),
      ),
      labelStyle: body(14, FontWeight.w400, textLo),
      hintStyle: body(14, FontWeight.w400, textLo),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: semantic.route,
        foregroundColor: semantic.onRoute,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.md,
          horizontal: AppSpace.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: body(16, FontWeight.w700, semantic.onRoute),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: semantic.route),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: semantic.route,
      foregroundColor: semantic.onRoute,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: textHi,
      contentTextStyle: body(14, FontWeight.w500, background),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    dividerTheme: DividerThemeData(color: semantic.hairline, thickness: 1),
  );
}

/// Monospaced style for geo-data (coordinates, trip IDs, counts) — the design
/// signature. Colour defaults to the theme's secondary text so it stays subtle.
TextStyle monoData(
  BuildContext context, {
  double size = 13,
  Color? color,
  FontWeight weight = FontWeight.w500,
}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
