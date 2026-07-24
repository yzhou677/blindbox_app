import 'package:flutter/material.dart';

import 'collectible_typography.dart';

/// Canonical named text roles for cross-screen use.
///
/// All roles delegate to [CollectibleTypography] for styles that already exist
/// there, or compose directly from [TextTheme] / [ColorScheme] for new roles.
/// Add new roles here rather than writing inline [TextStyle.copyWith] calls in
/// widget files.
///
/// Usage:
/// ```dart
/// Text('Market', style: AppTypography.tabTitle(textTheme, colorScheme));
/// ```
abstract final class AppTypography {
  AppTypography._();

  // ── Page / screen level ──────────────────────────────────────────────────

  /// Main-tab AppBar titles (Home, Market, Collection).
  /// Uses [TextTheme.titleLarge] tuned in [AppTheme] (w700, ~22 sp).
  static TextStyle tabTitle(TextTheme t, ColorScheme s) =>
      t.titleLarge!.copyWith(fontWeight: FontWeight.w700);

  /// Full-screen search overlay AppBar title.
  /// Uses [CollectibleTypography.editorialScreenTitle] (headlineSmall w700).
  static TextStyle screenTitle(TextTheme t, ColorScheme s) =>
      CollectibleTypography.editorialScreenTitle(t, s);

  // ── Section level ────────────────────────────────────────────────────────

  /// Section header title used by [CollectibleSectionHeader].
  /// Delegates to [CollectibleTypography.shelfSeriesTitle] (titleMedium w600).
  static TextStyle sectionTitle(TextTheme t, ColorScheme s) =>
      CollectibleTypography.shelfSeriesTitle(t, s);

  /// Small label above chip rails and taxonomy blocks (market, search, wishlist).
  /// labelSmall w600 with tight letter spacing.
  static TextStyle sectionLabel(TextTheme t, ColorScheme s) =>
      t.labelSmall!.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        color: s.onSurfaceVariant.withValues(alpha: 0.72),
      );

  // ── Card / row level ─────────────────────────────────────────────────────

  /// Primary title inside a card or list row (market, official feed, search).
  /// Delegates to [CollectibleTypography.catalogSeriesRowTitle] (titleSmall w600).
  static TextStyle cardTitle(TextTheme t, ColorScheme s) =>
      CollectibleTypography.catalogSeriesRowTitle(t, s);

  /// Row subtitle / meta line inside a card.
  /// Delegates to [CollectibleTypography.figureMeta] (labelSmall w500 muted).
  static TextStyle cardMeta(TextTheme t, ColorScheme s) =>
      CollectibleTypography.figureMeta(t, s);

  // ── Deck / flavor ────────────────────────────────────────────────────────

  /// Quiet descriptive copy below section titles and inside cards.
  /// Delegates to [CollectibleTypography.seriesBrandLine] (bodySmall w400 muted).
  static TextStyle deckText(TextTheme t, ColorScheme s) =>
      CollectibleTypography.seriesBrandLine(t, s);

  /// Supportive / meta text lines — dates, counts, secondary labels.
  /// Delegates to [CollectibleTypography.figureMeta] (labelSmall w500 muted).
  static TextStyle supportive(TextTheme t, ColorScheme s) =>
      CollectibleTypography.figureMeta(t, s);

  // ── Empty states ─────────────────────────────────────────────────────────

  /// Centered empty-state title (Wishlist, Market, Collection).
  static TextStyle emptyStateTitle(TextTheme t, ColorScheme s) =>
      t.titleSmall!.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        height: 1.25,
        color: s.onSurface,
      );

  /// Centered empty-state body under [emptyStateTitle].
  static TextStyle emptyStateBody(TextTheme t, ColorScheme s) => t.bodySmall!
      .copyWith(height: 1.4, color: s.onSurfaceVariant.withValues(alpha: 0.78));

  // ── Insights-specific ────────────────────────────────────────────────────

  /// Revealed Collector Type display name on the hero card.
  static TextStyle insightsHeroName(TextTheme t, ColorScheme s) =>
      CollectibleTypography.seriesHeroTitle(t, s).copyWith(
        fontSize: 28,
        letterSpacing: -0.5,
        height: 1.12,
        fontWeight: FontWeight.w700,
        color: s.onSurface.withValues(alpha: 0.96),
      );

  /// “Because …” line under the Collector Type name.
  static TextStyle insightsBecause(TextTheme t, ColorScheme s) =>
      t.bodyMedium!.copyWith(
        color: s.onSurface.withValues(alpha: 0.70),
        height: 1.38,
        fontWeight: FontWeight.w500,
      );

  /// Large totals / counts on the Collection Insights screen.
  /// titleLarge w700 with tighter tracking for numerals.
  static TextStyle insightsTotals(TextTheme t, ColorScheme s) =>
      t.titleLarge!.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        height: 1.02,
        color: s.onSurface.withValues(alpha: 0.94),
      );

  /// Archetype flavor / deck copy on the Collector Type result card.
  /// bodyLarge italic, softened to 72 % opacity.
  static TextStyle insightsFlavor(TextTheme t, ColorScheme s) =>
      t.bodyLarge!.copyWith(
        fontStyle: FontStyle.italic,
        height: 1.45,
        color: s.onSurface.withValues(alpha: 0.72),
      );

  /// Section / strip caption labels inside Insights (e.g. "Brands").
  /// labelSmall w600 with light letter spacing — quieter than [sectionTitle].
  static TextStyle insightsCaption(TextTheme t, ColorScheme s) =>
      t.labelSmall!.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.12,
        height: 1.2,
        color: s.onSurfaceVariant.withValues(alpha: 0.56),
      );
}
