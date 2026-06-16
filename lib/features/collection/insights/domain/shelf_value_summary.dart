import 'package:flutter/foundation.dart';

/// A single valued figure from the user's shelf.
@immutable
class ValuedFigure {
  const ValuedFigure({
    required this.shelfFigureId,
    required this.name,
    required this.seriesId,
    required this.seriesName,
    required this.estimatedValueUsd,
    required this.isSeriesEstimate,
    this.imageKey,
  });

  /// Shelf-local figure id ([ShelfFigure.id]).
  final String shelfFigureId;
  final String name;
  final String seriesId;
  final String seriesName;
  final double estimatedValueUsd;

  /// True when value comes from a series-level fallback, not a figure-specific
  /// snapshot. Callers should display a `~` prefix.
  final bool isSeriesEstimate;

  /// Catalog [imageKey] for thumbnail rendering; null for fully custom figures.
  final String? imageKey;
}

/// Aggregated market value for one series on the shelf.
@immutable
class SeriesValueEntry {
  const SeriesValueEntry({
    required this.seriesId,
    required this.seriesName,
    required this.totalValueUsd,
    required this.valuedFigureCount,
    required this.ownedFigureCount,
  });

  final String seriesId;
  final String seriesName;
  final double totalValueUsd;

  /// Owned figures in this series with a valid market snapshot.
  final int valuedFigureCount;

  /// Total owned figures in this series (with or without a snapshot).
  final int ownedFigureCount;
}

/// Rough tier for future use — not displayed in MVP.
enum CollectionValueTier { empty, small, medium, large, massive }

/// Aggregated market-value summary for all owned figures on the shelf.
@immutable
class ShelfValueSummary {
  const ShelfValueSummary({
    required this.totalValueUsd,
    required this.ownedCount,
    required this.valuedCount,
    required this.unavailableCount,
    required this.topFigures,
    required this.seriesBreakdown,
    required this.tier,
    required this.includesSeriesEstimates,
  });

  /// Sum of [MarketSnapshot.estimatedValueUsd] for all owned figures with a
  /// valid snapshot. Figures without a snapshot are excluded (never treated as
  /// $0).
  final double totalValueUsd;

  /// Total number of owned figures on the shelf.
  final int ownedCount;

  /// Owned figures with a valid market snapshot (figure-level or series
  /// fallback).
  final int valuedCount;

  /// Owned figures with no snapshot — excluded from [totalValueUsd].
  final int unavailableCount;

  /// Top 5 owned figures sorted by estimated value descending.
  final List<ValuedFigure> topFigures;

  /// Per-series breakdown, sorted by total value descending. Only includes
  /// series with at least one valued figure.
  final List<SeriesValueEntry> seriesBreakdown;

  /// Rough tier — stored for future use; not displayed in MVP.
  final CollectionValueTier tier;

  /// True when at least one valued figure used a series-level fallback snapshot.
  final bool includesSeriesEstimates;

  /// 0–100 integer coverage percentage.
  int get coveragePercent =>
      ownedCount == 0 ? 0 : ((valuedCount / ownedCount) * 100).round();

  /// Coverage sub-label for Collection Home and Insights overview.
  String get coverageLabel {
    final base = 'Based on $valuedCount of $ownedCount figures';
    if (includesSeriesEstimates) {
      return '$base · includes estimates';
    }
    return base;
  }

  bool get hasAnyValue => valuedCount > 0;

  /// Empty shelf or zero coverage.
  static const ShelfValueSummary none = ShelfValueSummary(
    totalValueUsd: 0,
    ownedCount: 0,
    valuedCount: 0,
    unavailableCount: 0,
    topFigures: [],
    seriesBreakdown: [],
    tier: CollectionValueTier.empty,
    includesSeriesEstimates: false,
  );
}
