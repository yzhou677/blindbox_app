import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/foundation.dart';

/// Regular-vs-secret completion semantics for one shelf series row.
@immutable
class SeriesCompletionResolution {
  const SeriesCompletionResolution({
    required this.regularSlotCount,
    required this.secretSlotCount,
    required this.regularOwnedCount,
    required this.secretOwnedCount,
  });

  final int regularSlotCount;
  final int secretSlotCount;
  final int regularOwnedCount;
  final int secretOwnedCount;

  /// All regular figures owned — or all slots when the series has no regular rows.
  bool get isCompleted {
    if (regularSlotCount > 0) {
      return regularOwnedCount >= regularSlotCount;
    }
    if (secretSlotCount > 0) {
      return secretOwnedCount >= secretSlotCount;
    }
    return false;
  }

  /// Completed with every secret figure also owned (visual tier only).
  bool get isMasterComplete =>
      isCompleted && secretSlotCount > 0 && secretOwnedCount >= secretSlotCount;

  int get progressDenominator =>
      regularSlotCount > 0 ? regularSlotCount : regularSlotCount + secretSlotCount;

  int get progressNumerator => regularSlotCount > 0
      ? regularOwnedCount
      : regularOwnedCount + secretOwnedCount;

  int get regularMissingCount =>
      regularSlotCount > 0 ? regularSlotCount - regularOwnedCount : 0;

  /// `1.0` when [isCompleted]; otherwise regular-weighted progress.
  ///
  /// This is the canonical **Regular Progress** ratio for one series:
  /// Secrets do not reduce the ratio once Regulars are complete (`isCompleted`
  /// ⇒ `1.0` even when Secrets are still missing).
  double get progressRatio {
    if (isCompleted) return 1.0;
    final d = progressDenominator;
    if (d <= 0) return 0;
    return (progressNumerator / d).clamp(0.0, 1.0);
  }

  /// Series can enter the Master path (has at least one Secret slot).
  bool get isMasterEligible => secretSlotCount > 0;

  /// Near Complete — same definition for sort, atmosphere, and Insights.
  bool get isNearComplete =>
      !isCompleted && progressRatio >= kSeriesNearCompleteRatio;
}

/// Canonical Near Complete threshold (Regular-weighted [progressRatio]).
const double kSeriesNearCompleteRatio = 0.85;

SeriesCompletionResolution resolveSeriesCompletion(
  ShelfSeries series,
  Map<String, TrackedFigure> states,
) {
  var regularSlots = 0;
  var secretSlots = 0;
  var regularOwned = 0;
  var secretOwned = 0;

  for (final fig in series.figures) {
    final owned = states[fig.id]?.owned == true;
    if (fig.isSecret) {
      secretSlots++;
      if (owned) secretOwned++;
    } else {
      regularSlots++;
      if (owned) regularOwned++;
    }
  }

  return SeriesCompletionResolution(
    regularSlotCount: regularSlots,
    secretSlotCount: secretSlots,
    regularOwnedCount: regularOwned,
    secretOwnedCount: secretOwned,
  );
}

/// Shelf-wide completion aggregates — single source for Summary / Insights /
/// Shelf Progress percentages and tier counts.
@immutable
class ShelfCompletionAggregate {
  const ShelfCompletionAggregate({
    required this.completedSeriesCount,
    required this.masterCompleteSeriesCount,
    required this.masterEligibleSeriesCount,
    required this.regularCompletionPercent,
  });

  static const empty = ShelfCompletionAggregate(
    completedSeriesCount: 0,
    masterCompleteSeriesCount: 0,
    masterEligibleSeriesCount: 0,
    regularCompletionPercent: 0,
  );

  /// Series with [SeriesCompletionResolution.isCompleted] (includes Master).
  final int completedSeriesCount;

  /// Series with [SeriesCompletionResolution.isMasterComplete].
  final int masterCompleteSeriesCount;

  /// Series with at least one Secret slot — Master Completion denominator.
  final int masterEligibleSeriesCount;

  /// Mean of per-series [SeriesCompletionResolution.progressRatio] × 100.
  ///
  /// Regular Progress aggregate: Secrets do not pull a Regular-complete series below
  /// 100% on this aggregate.
  final int regularCompletionPercent;

  /// Master Complete / Secret-bearing series; `0` when none are eligible.
  double get masterCompletionRatio {
    if (masterEligibleSeriesCount <= 0) return 0;
    return (masterCompleteSeriesCount / masterEligibleSeriesCount)
        .clamp(0.0, 1.0);
  }

  int get masterCompletionPercent =>
      (masterCompletionRatio * 100).round().clamp(0, 100);
}

/// Canonical shelf completion pass over [resolveSeriesCompletion].
ShelfCompletionAggregate aggregateShelfCompletion(CollectionSnapshot snap) {
  final series = snap.shelfSeries;
  if (series.isEmpty) return ShelfCompletionAggregate.empty;

  var completed = 0;
  var master = 0;
  var eligible = 0;
  var sumRatio = 0.0;

  for (final row in series) {
    final r = resolveSeriesCompletion(row, snap.figureStates);
    if (r.isCompleted) completed++;
    if (r.isMasterEligible) {
      eligible++;
      if (r.isMasterComplete) master++;
    }
    sumRatio += r.progressRatio;
  }

  return ShelfCompletionAggregate(
    completedSeriesCount: completed,
    masterCompleteSeriesCount: master,
    masterEligibleSeriesCount: eligible,
    regularCompletionPercent:
        ((sumRatio / series.length) * 100).round().clamp(0, 100),
  );
}

/// Shelf-wide completed / master-complete series counts for summary UI.
(int completed, int master) countShelfCompletionTiers(
  CollectionSnapshot snap,
) {
  final a = aggregateShelfCompletion(snap);
  return (a.completedSeriesCount, a.masterCompleteSeriesCount);
}
