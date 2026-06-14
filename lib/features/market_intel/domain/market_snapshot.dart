import 'package:flutter/foundation.dart';

/// Persisted sold-data market intelligence for one catalog figure or series.
///
/// Written by admin tools only; the Flutter app is read-only.
@immutable
class MarketSnapshot {
  const MarketSnapshot({
    required this.id,
    required this.level,
    this.figureId,
    required this.seriesId,
    required this.estimatedValueUsd,
    required this.trend,
    required this.confidence,
    required this.recentSalesCount,
    this.priceRangeMinUsd,
    this.priceRangeMaxUsd,
    required this.computedAt,
  });

  /// Document id — equals [figureId] for figure snapshots or [seriesId] for series snapshots.
  final String id;
  final SnapshotLevel level;

  /// Null when [level] is [SnapshotLevel.series].
  final String? figureId;

  /// Always set; enables batch queries by series in Firestore.
  final String seriesId;
  final double estimatedValueUsd;
  final MarketTrend trend;
  final SnapshotConfidence confidence;
  final int recentSalesCount;
  final double? priceRangeMinUsd;
  final double? priceRangeMaxUsd;
  final DateTime computedAt;

  /// True when this snapshot is a series-level fallback estimate.
  bool get isSeriesEstimate => level == SnapshotLevel.series;
}

enum SnapshotLevel { figure, series }

enum MarketTrend { rising, falling, stable, unknown }

enum SnapshotConfidence { high, low }
