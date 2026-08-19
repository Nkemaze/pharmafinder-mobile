import 'package:flutter/material.dart';

/// Design tokens from the PharmaFinder mobile design system.
///
/// Source: Stitch project "PharmaFinder Mobile App UI/UX" design system.
/// Palette is "Deep Medical Green" on a light mint surface, Inter typeface.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00513E);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0B6B53);
  static const Color onPrimaryContainer = Color(0xFF97E8CA);

  static const Color secondary = Color(0xFF006C4D);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF7BF6C4);
  static const Color onSecondaryContainer = Color(0xFF007151);

  static const Color tertiary = Color(0xFF374A44);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF4E625B);
  static const Color onTertiaryContainer = Color(0xFFC7DDD4);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color background = Color(0xFFF2FBFF);
  static const Color onBackground = Color(0xFF0F1E22);

  static const Color surface = Color(0xFFF2FBFF);
  static const Color onSurface = Color(0xFF0F1E22);
  static const Color surfaceVariant = Color(0xFFD6E5EC);
  static const Color onSurfaceVariant = Color(0xFF3F4944);

  static const Color outline = Color(0xFF6F7A74);
  static const Color outlineVariant = Color(0xFFBEC9C3);

  static const Color inverseSurface = Color(0xFF243238);
  static const Color inverseOnSurface = Color(0xFFE4F3FA);
  static const Color inversePrimary = Color(0xFF85D6B9);

  static const Color surfaceTint = Color(0xFF0B6B53);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFE7F6FD);
  static const Color surfaceContainer = Color(0xFFE1F0F7);
  static const Color surfaceContainerHigh = Color(0xFFDBEBF1);
  static const Color surfaceContainerHighest = Color(0xFFD6E5EC);

  static const Color primaryFixed = Color(0xFFA1F3D4);
  static const Color primaryFixedDim = Color(0xFF85D6B9);
  static const Color onPrimaryFixed = Color(0xFF002117);
  static const Color onPrimaryFixedVariant = Color(0xFF00513E);

  static const Color secondaryFixed = Color(0xFF7EF9C7);
  static const Color secondaryFixedDim = Color(0xFF60DCAC);
  static const Color onSecondaryFixed = Color(0xFF002115);
  static const Color onSecondaryFixedVariant = Color(0xFF00513A);

  static const Color tertiaryFixed = Color(0xFFD2E7DF);
  static const Color tertiaryFixedDim = Color(0xFFB6CBC3);
  static const Color onTertiaryFixed = Color(0xFF0C1F1A);
  static const Color onTertiaryFixedVariant = Color(0xFF374B44);

  // Semantic status colors used across the UI.
  static const Color openGreen = Color(0xFF2E7D32);
  static const Color openGreenBg = Color(0xFFE8F5E9);
}

/// Typography scale from the design system (Inter).
class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'Inter';

  static const TextStyle headlineLg = TextStyle(
    fontFamily: _font,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
    letterSpacing: -0.02 * 24,
  );

  static const TextStyle headlineXl = TextStyle(
    fontFamily: _font,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 36 / 28,
    letterSpacing: -0.02 * 28,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: _font,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 0.05 * 12,
  );
}

/// App-level spacing helpers (8px grid).
class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const EdgeInsets pageMargin = EdgeInsets.all(md);
  static const EdgeInsets horizontalMargin = EdgeInsets.symmetric(horizontal: md);
  static const double touchTarget = 48;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      inversePrimary: AppColors.inversePrimary,
      surfaceTint: AppColors.surfaceTint,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      primaryFixed: AppColors.primaryFixed,
      primaryFixedDim: AppColors.primaryFixedDim,
      onPrimaryFixed: AppColors.onPrimaryFixed,
      onPrimaryFixedVariant: AppColors.onPrimaryFixedVariant,
      secondaryFixed: AppColors.secondaryFixed,
      secondaryFixedDim: AppColors.secondaryFixedDim,
      onSecondaryFixed: AppColors.onSecondaryFixed,
      onSecondaryFixedVariant: AppColors.onSecondaryFixedVariant,
      tertiaryFixed: AppColors.tertiaryFixed,
      tertiaryFixedDim: AppColors.tertiaryFixedDim,
      onTertiaryFixed: AppColors.onTertiaryFixed,
      onTertiaryFixedVariant: AppColors.onTertiaryFixedVariant,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.headlineLg,
        displayMedium: AppTextStyles.headlineLg,
        displaySmall: AppTextStyles.headlineLg,
        headlineLarge: AppTextStyles.headlineLg,
        headlineMedium: AppTextStyles.headlineMd,
        headlineSmall: AppTextStyles.headlineMd,
        titleLarge: AppTextStyles.headlineMd,
        titleMedium: AppTextStyles.bodyLg,
        titleSmall: AppTextStyles.bodySm,
        bodyLarge: AppTextStyles.bodyLg,
        bodyMedium: AppTextStyles.bodySm,
        bodySmall: AppTextStyles.bodySm,
        labelLarge: AppTextStyles.bodySm,
        labelMedium: AppTextStyles.labelMd,
        labelSmall: AppTextStyles.labelMd,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(AppSpace.touchTarget),
          textStyle: AppTextStyles.labelMd,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(AppSpace.touchTarget),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHighest,
        hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.outlineVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
