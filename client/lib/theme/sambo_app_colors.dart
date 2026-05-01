import 'package:flutter/material.dart';

/// Centralised palette for the app. Every screen/widget should pull colours
/// from here rather than embedding hex literals — that way a re-skin is one
/// file change, not a grep across the codebase.
///
/// Semantics follow Material 3's `ColorScheme` slots so the values map cleanly
/// onto `ColorScheme(...)` in the app's theme.
class SamboAppColors {
  SamboAppColors._();

  // ---- Brand ---------------------------------------------------------------

  /// Action / call-to-action colour. Buttons, FABs, links.
  static const Color primary = Color(0xFFD2691E);          // burnt orange
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Secondary accent — used for highlights, dividers, soft emphasis.
  /// Picked to nod toward the gold flourish in the app logo.
  static const Color secondary = Color(0xFFE8B447);        // soft gold
  static const Color onSecondary = Color(0xFF1B263B);

  /// Tertiary — reserved for chips, tags, status pills.
  static const Color tertiary = Color(0xFF6B8FB5);         // muted blue
  static const Color onTertiary = Color(0xFFFFFFFF);

  // ---- Surfaces / backgrounds ---------------------------------------------

  /// Whole-app background.
  static const Color background = Color(0xFF1B263B);       // dark navy

  /// Cards, dialogs, elevated containers.
  static const Color surface = Color(0xFF233044);          // slightly lifted

  /// Highest-elevation surfaces (e.g. modal sheets).
  static const Color surfaceContainerHighest = Color(0xFF2C3A52);

  static const Color onBackground = Color(0xFFE8ECF1);
  static const Color onSurface = Color(0xFFE8ECF1);
  static const Color onSurfaceVariant = Color(0xFFB7C0CE);

  // ---- Status -------------------------------------------------------------

  static const Color error = Color(0xFFE5747B);            // soft coral
  static const Color onError = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF5BAB7A);

  // ---- Misc ---------------------------------------------------------------

  static const Color outline = Color(0xFF4A5568);
  static const Color shadow = Color(0xFF000000);

  // ---- ColorScheme builder -----------------------------------------------

  /// Pre-built dark-mode `ColorScheme`. Pass to `ThemeData(colorScheme: ...)`.
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    tertiary: tertiary,
    onTertiary: onTertiary,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainerHighest: surfaceContainerHighest,
    error: error,
    onError: onError,
    outline: outline,
    shadow: shadow,
  );
}
