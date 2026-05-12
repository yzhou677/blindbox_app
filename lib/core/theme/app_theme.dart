import 'package:flutter/material.dart';

/// Pastel, cozy Material 3 themes — designer toy / shelf energy, not enterprise UI.
abstract final class AppTheme {
  /// Soft mauve–rose seed (POP MART–adjacent pastels, low harsh contrast).
  static const Color _seed = Color(0xFFC9A8D8);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return _base(colorScheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: Color.lerp(
        colorScheme.surfaceContainerLowest,
        const Color(0xFFFFF8FC),
        0.35,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return _base(colorScheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme colorScheme, Brightness brightness) {
    final seed = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
    );
    final t = seed.textTheme;

    return seed.copyWith(
      textTheme: t.copyWith(
        titleLarge: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.28,
          height: 1.22,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.18,
          height: 1.25,
        ),
        titleSmall: t.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.08,
          height: 1.28,
        ),
        headlineMedium: t.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.45,
          height: 1.15,
        ),
        headlineSmall: t.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.35,
          height: 1.18,
        ),
        bodyLarge: t.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.38,
          letterSpacing: 0.06,
        ),
        bodySmall: t.bodySmall?.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.32,
          letterSpacing: 0.06,
        ),
        labelLarge: t.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: t.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.18,
        ),
        labelSmall: t.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.32,
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.28,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        indicatorColor: colorScheme.secondaryContainer.withValues(alpha: 0.85),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
            size: 24,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        labelStyle: t.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.35),
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
