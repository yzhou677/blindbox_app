import 'package:flutter/material.dart';

/// Warm, collectible-focused Material 3 themes (light + dark).
abstract final class AppTheme {
  static const Color _seed = Color(0xFF8B7355);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );
    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );
    return _base(colorScheme);
  }

  static ThemeData _base(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
