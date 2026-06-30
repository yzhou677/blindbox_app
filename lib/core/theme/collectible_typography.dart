import 'package:flutter/material.dart';

/// IP → Series → Figure hierarchy for shelf / catalog / discovery surfaces.
abstract final class CollectibleTypography {
  static TextStyle editorialScreenTitle(TextTheme t, ColorScheme scheme) {
    return t.headlineSmall!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.02,
      height: 1.2,
      color: scheme.onSurface,
    );
  }

  /// Primary series name on detail sheets and release pages.
  static TextStyle seriesHeroTitle(TextTheme t, ColorScheme scheme) {
    return t.headlineSmall!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.02,
      height: 1.18,
      color: scheme.onSurface,
    );
  }

  /// IP line under a series hero (quieter than the title).
  static TextStyle seriesIpLine(TextTheme t, ColorScheme scheme) {
    return t.labelLarge!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.08,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
    );
  }

  /// Brand / studio under IP on series surfaces.
  static TextStyle seriesBrandLine(TextTheme t, ColorScheme scheme) {
    return t.bodySmall!.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0.04,
      height: 1.35,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.58),
    );
  }

  /// Shelf row series title.
  static TextStyle shelfSeriesTitle(TextTheme t, ColorScheme scheme) {
    return t.titleMedium!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.22,
      color: scheme.onSurface,
    );
  }

  /// Emotional progress line — supportive, not competing with the series title.
  static TextStyle shelfProgressLine(TextTheme t, ColorScheme scheme) {
    return t.bodyMedium!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.02,
      height: 1.32,
      color: scheme.onSurface.withValues(alpha: 0.82),
    );
  }

  static TextStyle shelfProgressMeta(TextTheme t, ColorScheme scheme) {
    return t.bodySmall!.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0.04,
      height: 1.35,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
    );
  }

  /// Calm regular-complete badge on shelf cards.
  static TextStyle shelfCompleteStatLine(TextTheme t, ColorScheme scheme) {
    return shelfProgressLine(t, scheme).copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface.withValues(alpha: 0.72),
    );
  }

  /// Master-complete achievement — warmer accent, stronger weight.
  static TextStyle shelfMasterCompleteStatLine(TextTheme t, ColorScheme scheme) {
    final gold = Color.lerp(scheme.primary, const Color(0xFFC9A227), 0.68)!;
    return shelfProgressLine(t, scheme).copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.04,
      color: gold,
    );
  }

  /// Quiet section label inside the series figure sheet.
  static TextStyle shelfFigureSheetSectionLabel(
    TextTheme t,
    ColorScheme scheme, {
    bool accent = false,
  }) {
    final color = accent
        ? Color.lerp(
            scheme.onSurfaceVariant,
            const Color(0xFFC9A227),
            0.32,
          )!.withValues(alpha: 0.84)
        : scheme.onSurfaceVariant.withValues(alpha: 0.68);
    return t.labelSmall!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.28,
      height: 1.3,
      color: color,
    );
  }

  /// Figure name in rails, capsules, and gallery footer.
  static TextStyle figureCaption(TextTheme t, ColorScheme scheme) {
    return t.labelLarge!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.04,
      height: 1.2,
      color: scheme.onSurface.withValues(alpha: 0.88),
    );
  }

  static TextStyle figureMeta(TextTheme t, ColorScheme scheme) {
    return t.labelSmall!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
  }

  /// Catalog search / browse row — series first.
  static TextStyle catalogSeriesRowTitle(TextTheme t, ColorScheme scheme) {
    return t.titleSmall!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.02,
      color: scheme.onSurface,
    );
  }

  static TextStyle catalogSeriesRowMeta(TextTheme t, ColorScheme scheme) {
    return t.bodySmall!.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0.03,
      height: 1.3,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
  }

  static TextStyle catalogSeriesRowIp(TextTheme t, ColorScheme scheme) {
    return t.labelMedium!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.06,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.48),
    );
  }
}
