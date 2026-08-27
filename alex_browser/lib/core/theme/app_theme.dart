import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Centralized theme definitions for Alex Browser.
///
/// The visual language favors a clean, modern browser chrome: rounded
/// address bar, subtle elevation, no heavy blur, and clear affordances
/// for navigation controls — inspired by the best parts of Chrome, Opera,
/// and Safari without imitating any single one exactly.
class AppTheme {
  AppTheme._();

  static const Color _seedLight = Color(0xFF2A5CE0);
  static const Color _seedDark = Color(0xFF6C9BFF);

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seedLight,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surface,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.6,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seedDark,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surface,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.6,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Private browsing gets a visually distinct (dark, slightly purple-tinted)
/// theme so users always have a clear visual cue they are in a private tab —
/// matching conventions established by Chrome and Safari.
class PrivateModeTheme {
  PrivateModeTheme._();

  static const Color background = Color(0xFF1A1625);
  static const Color surface = Color(0xFF241E33);
  static const Color accent = Color(0xFF9B7EDE);

  static ThemeData theme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
