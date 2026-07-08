import 'package:flutter/material.dart';

/// Central design system for PDF Viewer Pro — palette, gradients, typography and
/// light/dark [ThemeData]. Matches the Stitch design.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF4F46E5); // indigo
  static const secondary = Color(0xFF7C3AED); // violet
  static const accent = Color(0xFFF59E0B); // gold (highlights)
  static const pdfRed = Color(0xFFE11D48);

  // Gradient stops (Open File button, hero cards, splash)
  static const gradStart = Color(0xFF6366F1);
  static const gradEnd = Color(0xFF8B5CF6);

  // Light neutrals
  static const lightBg = Color(0xFFF7F8FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1F2F9);
  static const onLight = Color(0xFF1E1B2E);
  static const onLightMuted = Color(0xFF6B7280);

  // Dark neutrals
  static const darkBg = Color(0xFF0E0E12);
  static const darkSurface = Color(0xFF17171F);
  static const darkSurfaceAlt = Color(0xFF20202B);
  static const onDark = Color(0xFFE7E5F0);
  static const onDarkMuted = Color(0xFF9CA3AF);

  // Semantic
  static const success = Color(0xFF22C55E);

  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradStart, gradEnd],
  );

  static const brandGradientDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradStart, gradEnd],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerHighest:
          isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
      onSurface: isDark ? AppColors.onDark : AppColors.onLight,
      error: const Color(0xFFEF4444),
    );

    final baseText = isDark ? AppColors.onDark : AppColors.onLight;

    final textTheme = TextTheme(
      displaySmall: TextStyle(
          fontFamily: 'Sora',
          fontWeight: FontWeight.w700,
          fontSize: 30,
          color: baseText),
      headlineMedium: TextStyle(
          fontFamily: 'Sora',
          fontWeight: FontWeight.w700,
          fontSize: 26,
          color: baseText),
      headlineSmall: TextStyle(
          fontFamily: 'Sora',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: baseText),
      titleLarge: TextStyle(
          fontFamily: 'Sora',
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: baseText),
      titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: baseText),
      bodyLarge: TextStyle(
          fontFamily: 'Inter', fontSize: 16, color: baseText),
      bodyMedium: TextStyle(
          fontFamily: 'Inter', fontSize: 14, color: baseText),
      labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: baseText),
      labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: isDark ? AppColors.onDarkMuted : AppColors.onLightMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      fontFamily: 'Inter',
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        foregroundColor: baseText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppColors.primary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: scheme.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        hintStyle: TextStyle(
            color: isDark ? AppColors.onDarkMuted : AppColors.onLightMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
      ),
    );
  }
}
