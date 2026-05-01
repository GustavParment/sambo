import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sambo/theme/sambo_app_colors.dart';

/// Builds the app's `ThemeData` from [SamboAppColors] + Inter typography.
/// Centralised so widget-level styling changes (radii, padding, elevation)
/// happen in one place.
class SamboTheme {
  SamboTheme._();

  static const _radius = 16.0;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: SamboAppColors.onSurface,
      displayColor: SamboAppColors.onSurface,
    );

    return base.copyWith(
      colorScheme: SamboAppColors.darkScheme,
      scaffoldBackgroundColor: SamboAppColors.background,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: SamboAppColors.background,
        foregroundColor: SamboAppColors.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      cardTheme: CardThemeData(
        color: SamboAppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SamboAppColors.primary,
          foregroundColor: SamboAppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SamboAppColors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          side: const BorderSide(color: SamboAppColors.outline),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: SamboAppColors.primary,
        foregroundColor: SamboAppColors.onPrimary,
        elevation: 4,
        extendedPadding: EdgeInsets.symmetric(horizontal: 20),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SamboAppColors.surface,
        indicatorColor: SamboAppColors.primary.withValues(alpha: 0.18),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? SamboAppColors.primary
                : SamboAppColors.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? SamboAppColors.primary
                : SamboAppColors.onSurfaceVariant,
          );
        }),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SamboAppColors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: SamboAppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: SamboAppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: SamboAppColors.outline,
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}
