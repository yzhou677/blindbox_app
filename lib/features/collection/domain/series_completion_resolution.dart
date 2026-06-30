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
  double get progressRatio {
    if (isCompleted) return 1.0;
    final d = progressDenominator;
    if (d <= 0) return 0;
    return (progressNumerator / d).clamp(0.0, 1.0);
  }
}

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

/// Shelf-wide completed / master-complete series counts for summary UI.
(int completed, int master) countShelfCompletionTiers(
  CollectionSnapshot snap,
) {
  var completed = 0;
  var master = 0;
  for (final series in snap.shelfSeries) {
    final r = resolveSeriesCompletion(series, snap.figureStates);
    if (r.isCompleted) completed++;
    if (r.isMasterComplete) master++;
  }
  return (completed, master);
}
