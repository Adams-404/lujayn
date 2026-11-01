import 'package:flutter/material.dart';
import 'app_theme_choice.dart';
import 'app_typography.dart';

/// Central source of truth for Lujayn's five named themes.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => forChoice(AppThemeChoice.silver);
  static ThemeData get darkTheme => forChoice(AppThemeChoice.dusk);

  static Color accentFor(AppThemeChoice choice) => _paletteFor(choice).accent;

  static Color onAccentFor(AppThemeChoice choice) =>
      _paletteFor(choice).onAccent;

  static ThemeData forChoice(AppThemeChoice choice) {
    final palette = _paletteFor(choice);
    final brightness = palette.brightness;
    final textTheme = AppTypography.createTextTheme(
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      textTertiary: palette.textTertiary,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
    ).copyWith(
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.secondary,
      onSecondary: palette.onAccent,
      tertiary: palette.success,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      error: palette.error,
      onError: Colors.white,
      outline: palette.outline,
      outlineVariant: palette.outline.withValues(alpha: 0.65),
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surfaceElevated,
      surfaceContainerHigh: palette.surfaceElevated,
      surfaceContainerHighest: palette.surfaceElevated,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: palette.textTertiary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        indicatorColor: palette.accent.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: palette.outline.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static _ThemePalette _paletteFor(AppThemeChoice choice) {
    switch (choice) {
      case AppThemeChoice.system:
      case AppThemeChoice.silver:
        return const _ThemePalette(
          brightness: Brightness.light,
          background: Color(0xFFF4F6F7),
          surface: Color(0xFFFFFFFF),
          surfaceElevated: Color(0xFFEBEFF1),
          textPrimary: Color(0xFF20272C),
          textSecondary: Color(0xFF56636B),
          textTertiary: Color(0xFF78858D),
          outline: Color(0xFFD6DDE1),
          accent: Color(0xFF526A78),
          onAccent: Colors.white,
          secondary: Color(0xFF8798A2),
          success: Color(0xFF47745B),
          error: Color(0xFFB64242),
        );
      case AppThemeChoice.paper:
        return const _ThemePalette(
          brightness: Brightness.light,
          background: Color(0xFFF5F0E7),
          surface: Color(0xFFFFFCF5),
          surfaceElevated: Color(0xFFEDE5D8),
          textPrimary: Color(0xFF302B25),
          textSecondary: Color(0xFF6D655A),
          textTertiary: Color(0xFF898073),
          outline: Color(0xFFDED4C5),
          accent: Color(0xFF795746),
          onAccent: Colors.white,
          secondary: Color(0xFFA17B62),
          success: Color(0xFF52704C),
          error: Color(0xFFB44338),
        );
      case AppThemeChoice.sage:
        return const _ThemePalette(
          brightness: Brightness.light,
          background: Color(0xFFF0F4EF),
          surface: Color(0xFFFBFDF9),
          surfaceElevated: Color(0xFFE5EDE3),
          textPrimary: Color(0xFF25332A),
          textSecondary: Color(0xFF5D6C61),
          textTertiary: Color(0xFF7D8B80),
          outline: Color(0xFFD1DDD1),
          accent: Color(0xFF466A50),
          onAccent: Colors.white,
          secondary: Color(0xFF829C83),
          success: Color(0xFF3F7651),
          error: Color(0xFFB4443D),
        );
      case AppThemeChoice.dusk:
        return const _ThemePalette(
          brightness: Brightness.dark,
          background: Color(0xFF17191D),
          surface: Color(0xFF202329),
          surfaceElevated: Color(0xFF292E35),
          textPrimary: Color(0xFFF0F1F2),
          textSecondary: Color(0xFFB2B8BE),
          textTertiary: Color(0xFF89929A),
          outline: Color(0xFF3B424A),
          accent: Color(0xFFB9C5CD),
          onAccent: Color(0xFF20252A),
          secondary: Color(0xFF8FA0AB),
          success: Color(0xFF8DB79A),
          error: Color(0xFFFF8A80),
        );
      case AppThemeChoice.amoled:
        return const _ThemePalette(
          brightness: Brightness.dark,
          background: Color(0xFF000000),
          surface: Color(0xFF050505),
          surfaceElevated: Color(0xFF111111),
          textPrimary: Color(0xFFF5F5F5),
          textSecondary: Color(0xFFB8B8B8),
          textTertiary: Color(0xFF898989),
          outline: Color(0xFF292929),
          accent: Color(0xFFC8D1D8),
          onAccent: Color(0xFF080808),
          secondary: Color(0xFF9CAAB3),
          success: Color(0xFF8EC69B),
          error: Color(0xFFFF8A80),
        );
    }
  }
}

class _ThemePalette {
  const _ThemePalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.outline,
    required this.accent,
    required this.onAccent,
    required this.secondary,
    required this.success,
    required this.error,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color outline;
  final Color accent;
  final Color onAccent;
  final Color secondary;
  final Color success;
  final Color error;
}
