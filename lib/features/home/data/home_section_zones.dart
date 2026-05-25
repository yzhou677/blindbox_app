import 'package:flutter/material.dart';

/// Soft shelf mats for Home rails — [ColorScheme] only, no extra framing.
/// Section identity comes from color + spacing; cards keep their own shells.
abstract final class HomeSectionZones {
  /// Warm editorial wash behind Official drops — quieter than Latest so rails stay balanced.
  static Color officialFeedMat(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final wash = Color.lerp(
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      isLight ? 0.34 : 0.28,
    )!.withValues(alpha: isLight ? 0.36 : 0.28);
    return Color.lerp(scheme.surface, wash, isLight ? 0.26 : 0.24)!;
  }

  /// Lavender–peach wash behind Latest Drops.
  static Color latestDropsMat(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final wash = Color.lerp(
      scheme.primaryContainer,
      scheme.secondaryContainer,
      isLight ? 0.42 : 0.28,
    )!.withValues(alpha: isLight ? 0.48 : 0.36);
    return Color.lerp(scheme.surface, wash, isLight ? 0.38 : 0.36)!;
  }

  /// Cool mint–lilac wash behind Trending series.
  static Color trendingSeriesMat(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final wash = Color.lerp(
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
      isLight ? 0.32 : 0.22,
    )!.withValues(alpha: isLight ? 0.5 : 0.38);
    return Color.lerp(scheme.surface, wash, isLight ? 0.36 : 0.34)!;
  }
}
