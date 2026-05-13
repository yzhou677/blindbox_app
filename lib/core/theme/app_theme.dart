import 'package:flutter/material.dart';

import 'collectible_shape.dart';

/// Pastel, cozy Material 3 — designer toy shelf / blind-box companion (not generic MD).
abstract final class AppTheme {
  /// Lavender–lilac seed; secondary accents nudge peach & cream in [_tunedScheme].
  static const Color _seed = Color(0xFFB8A0D4);

  static ColorScheme _tunedScheme(ColorScheme base, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return base.copyWith(
      // Signature lavender — interactive “collectible magic” (not neon, not flooded).
      primary: isLight ? const Color(0xFF6A5685) : const Color(0xFFD8C8EC),
      onPrimary: isLight ? const Color(0xFFFFFBFA) : const Color(0xFF241C30),
      primaryContainer: isLight ? const Color(0xFFE8DEF5) : const Color(0xFF423657),
      onPrimaryContainer: isLight ? const Color(0xFF342A40) : const Color(0xFFEAE2F6),
      // Creamy peach — warmth & shelf nostalgia (secondary to lavender).
      secondary: isLight ? const Color(0xFFE7A088) : const Color(0xFFFFCAB0),
      onSecondary: isLight ? const Color(0xFF3D291F) : const Color(0xFF3D2418),
      secondaryContainer: isLight ? const Color(0xFFFFF0E8) : const Color(0xFF4A3428),
      onSecondaryContainer: isLight ? const Color(0xFF4A3028) : const Color(0xFFFFE1D4),
      // Lilac highlights — companions to primary for depth & completion sparkle.
      tertiary: isLight ? const Color(0xFFB39FD4) : const Color(0xFFC4B2E0),
      onTertiary: isLight ? const Color(0xFF2A2438) : const Color(0xFF1E1828),
      tertiaryContainer: isLight ? const Color(0xFFF2EDFA) : const Color(0xFF3F384F),
      onTertiaryContainer: isLight ? const Color(0xFF3A3248) : const Color(0xFFE8E0F4),
      // Warm shelf neutrals — calm fields with a whisper of lilac paper.
      surface: isLight ? const Color(0xFFFFFAF8) : base.surface,
      surfaceContainerLow: isLight ? const Color(0xFFFFF7F5) : base.surfaceContainerLow,
      surfaceContainer: isLight ? const Color(0xFFF7F2FA) : base.surfaceContainer,
      surfaceContainerHigh: isLight ? const Color(0xFFF0EBF5) : base.surfaceContainerHigh,
      outlineVariant: isLight ? const Color(0xFFD8CFE0) : base.outlineVariant,
    );
  }

  static ThemeData light() {
    final raw = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final colorScheme = _tunedScheme(raw, Brightness.light);
    return _base(colorScheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: Color.lerp(
        colorScheme.surfaceContainerLowest,
        const Color(0xFFFFF6F2),
        0.38,
      ),
    );
  }

  static ThemeData dark() {
    final raw = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final colorScheme = _tunedScheme(raw, Brightness.dark);
    return _base(colorScheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme colorScheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final seed = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
    );
    final t = seed.textTheme;

    return seed.copyWith(
      textTheme: t.copyWith(
        titleLarge: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.26,
          height: 1.2,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.14,
          height: 1.22,
        ),
        titleSmall: t.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.06,
          height: 1.26,
        ),
        headlineMedium: t.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.42,
          height: 1.14,
        ),
        headlineSmall: t.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.32,
          height: 1.16,
        ),
        bodyLarge: t.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: 0.04,
        ),
        bodyMedium: t.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.38,
          letterSpacing: 0.03,
        ),
        bodySmall: t.bodySmall?.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.36,
          letterSpacing: 0.05,
        ),
        labelLarge: t.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.05,
        ),
        labelMedium: t.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
        ),
        labelSmall: t.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: colorScheme.primary.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: colorScheme.primary.withValues(alpha: isLight ? 0.08 : 0.14),
        titleTextStyle: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.24,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: Color.lerp(
          colorScheme.surfaceContainerLow,
          colorScheme.primaryContainer,
          isLight ? 0.14 : 0.1,
        ),
        surfaceTintColor: colorScheme.primary.withValues(alpha: isLight ? 0.12 : 0.16),
        indicatorColor: Color.lerp(
          colorScheme.primaryContainer,
          colorScheme.primary,
          isLight ? 0.22 : 0.28,
        )!.withValues(alpha: isLight ? 0.62 : 0.48),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return (t.labelMedium ?? t.labelSmall)!.copyWith(
            fontSize: 12,
            letterSpacing: 0.1,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.05,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.86),
            size: 24,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CollectibleShape.mat),
        ),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        elevation: 0,
        pressElevation: 0,
        selectedColor: colorScheme.primaryContainer.withValues(alpha: isLight ? 0.88 : 0.55),
        checkmarkColor: colorScheme.primary,
        labelStyle: t.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.12,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: colorScheme.shadow.withValues(alpha: isLight ? 0.08 : 0.35),
        surfaceTintColor: colorScheme.primary.withValues(alpha: isLight ? 0.06 : 0.12),
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: CollectibleShape.shellRadius,
          side: BorderSide(
            color: Color.lerp(
              colorScheme.outlineVariant,
              colorScheme.primary,
              isLight ? 0.1 : 0.14,
            )!.withValues(alpha: isLight ? 0.5 : 0.42),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: CollectibleShape.shellRadius,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.25),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.55 : 0.42),
        border: OutlineInputBorder(
          borderRadius: CollectibleShape.fieldRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CollectibleShape.fieldRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.32)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CollectibleShape.fieldRadius,
          borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.45), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CollectibleShape.mat),
          ),
        ),
      ),
    );
  }
}
