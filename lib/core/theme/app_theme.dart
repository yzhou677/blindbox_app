import 'package:flutter/material.dart';

import 'collectible_shape.dart';
import 'collectible_tokens.dart';

/// Pastel, cozy Material 3 — designer toy shelf / blind-box companion (not generic MD).
abstract final class AppTheme {
  /// Deeper lavender seed — premium packaging / soft cyber-y2k without neon.
  static const Color _seed = Color(0xFFA892CC);

  static ColorScheme _tunedScheme(ColorScheme base, Brightness brightness) {
    if (brightness == Brightness.light) {
      return base.copyWith(
        // Candy-wisteria primary — packaging jelly, still office-readable.
        primary: const Color(0xFF6652A5),
        onPrimary: const Color(0xFFFFFBFE),
        primaryContainer: const Color(0xFFE4D6F8),
        onPrimaryContainer: const Color(0xFF2A1F3D),
        secondary: const Color(0xFFE59878),
        onSecondary: const Color(0xFF3D291F),
        secondaryContainer: const Color(0xFFFFF0E8),
        onSecondaryContainer: const Color(0xFF4A3028),
        tertiary: const Color(0xFFB49AE0),
        onTertiary: const Color(0xFF2A2438),
        tertiaryContainer: const Color(0xFFF0E9FA),
        onTertiaryContainer: const Color(0xFF38304A),
        // Airy shelf — card [surface] and floor stay close for soft hierarchy.
        surface: const Color(0xFFFFFAFC),
        surfaceContainerLow: const Color(0xFFF5F0FA),
        surfaceContainer: const Color(0xFFEBE4F3),
        surfaceContainerHigh: const Color(0xFFE0D7EE),
        outlineVariant: const Color(0xFFC8B8D8),
        shadow: Color.lerp(base.shadow, const Color(0xFF6B5A8A), 0.35)!,
      );
    }
    // Dark: plum–blackberry charcoal (never AMOLED void); purple reads candy-lit.
    return base.copyWith(
      primary: const Color(0xFFDCC2FC),
      onPrimary: const Color(0xFF261C34),
      primaryContainer: const Color(0xFF54446F),
      onPrimaryContainer: const Color(0xFFEEE6FB),
      secondary: const Color(0xFFFFCDB5),
      onSecondary: const Color(0xFF301F18),
      secondaryContainer: const Color(0xFF5A4034),
      onSecondaryContainer: const Color(0xFFFFE2D6),
      tertiary: const Color(0xFFCDB8EC),
      onTertiary: const Color(0xFF1E1828),
      tertiaryContainer: const Color(0xFF453D58),
      onTertiaryContainer: const Color(0xFFEAE2FA),
      surface: const Color(0xFF2F293C),
      surfaceContainerLow: const Color(0xFF252030),
      surfaceContainer: const Color(0xFF322B3E),
      surfaceContainerHigh: const Color(0xFF3B3348),
      onSurface: const Color(0xFFF2EAF9),
      onSurfaceVariant: const Color(0xFFC9BDD6),
      outline: const Color(0xFF9488A8),
      outlineVariant: const Color(0xFF534A64),
      shadow: const Color(0xFF181224),
      scrim: const Color(0xFF120C18),
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
        colorScheme.surfaceContainerLow,
        colorScheme.surface,
        0.42,
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
    return _base(colorScheme, Brightness.dark).copyWith(
      scaffoldBackgroundColor: Color.lerp(
        colorScheme.surfaceContainerLow,
        colorScheme.primaryContainer,
        0.06,
      ),
    );
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
      extensions: <ThemeExtension<dynamic>>[
        CollectibleTokens.forBrightness(brightness),
      ],
      textTheme: t.copyWith(
        titleLarge: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.28,
          height: 1.18,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
          height: 1.2,
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
      highlightColor: colorScheme.primary.withValues(alpha: isLight ? 0.07 : 0.055),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: colorScheme.primary.withValues(alpha: isLight ? 0.1 : 0.12),
        titleTextStyle: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.24,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: Colors.transparent,
        surfaceTintColor: colorScheme.primary.withValues(alpha: isLight ? 0.1 : 0.11),
        indicatorColor: Color.lerp(
          colorScheme.primaryContainer,
          colorScheme.primary,
          isLight ? 0.34 : 0.3,
        )!.withValues(alpha: isLight ? 0.78 : 0.48),
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
          color: Color.lerp(
            colorScheme.outlineVariant,
            colorScheme.primary,
            isLight ? 0.1 : 0.14,
          )!.withValues(alpha: isLight ? 0.42 : 0.35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        elevation: 0,
        pressElevation: 0,
        selectedColor: Color.lerp(
          colorScheme.primaryContainer,
          colorScheme.tertiaryContainer,
          isLight ? 0.12 : 0.08,
        )!.withValues(alpha: isLight ? 0.98 : 0.62),
        checkmarkColor: colorScheme.primary,
        labelStyle: t.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.12,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isLight ? 2 : 1,
        shadowColor: Color.lerp(
          colorScheme.shadow,
          colorScheme.primary,
          isLight ? 0.12 : 0.14,
        )!.withValues(alpha: isLight ? 0.11 : 0.22),
        surfaceTintColor: colorScheme.primary.withValues(alpha: isLight ? 0.085 : 0.1),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: CollectibleShape.shellRadius,
          side: BorderSide(
            color: Color.lerp(
              colorScheme.outlineVariant,
              colorScheme.primary,
              isLight ? 0.14 : 0.2,
            )!.withValues(alpha: isLight ? 0.45 : 0.38),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: isLight ? 0.2 : 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: CollectibleShape.shellRadius,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: isLight ? 0.22 : 0.18),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.5 : 0.38),
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
          borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.44), width: 1.35),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: isLight ? 1 : 0,
          shadowColor: isLight
              ? Color.lerp(colorScheme.shadow, colorScheme.primary, 0.14)!
                  .withValues(alpha: 0.14)
              : Color.lerp(colorScheme.shadow, colorScheme.primary, 0.2)!
                  .withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CollectibleShape.mat),
          ),
        ),
      ),
    );
  }
}
