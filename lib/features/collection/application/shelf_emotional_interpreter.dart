import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_stat_keys.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';

// TODO(perf/scale): interpretShelf runs synchronously on the UI isolate.  At
// indie scale (≤100 series) it completes in <10 ms and does not need isolate
// offloading.  Move to Isolate.run when the function is called in hot paths
// (e.g. every shelf write) AND profiling shows it exceeding ~30 ms on target
// devices.  Candidates: CollectionNotifier._commit → recordTransitions →
// _eraFromSnapshot, and shelfEmotionalProfileProvider rebuild on cycleFigure.
ShelfEmotionalProfile interpretShelf(CollectionSnapshot snap) {
  if (snap.shelfSeries.isEmpty) {
    return const ShelfEmotionalProfile(
      shelfMood: ShelfMood.growing,
      interpretationConfidence: ShelfInterpretationConfidence.low,
      secretOwnedCount: 0,
      secretSlotCount: 0,
      seriesCompleteCount: 0,
      editorialThemes: [],
    );
  }

  var secretSlots = 0;
  var secretOwned = 0;
  var seriesComplete = 0;
  var nearCompleteSeries = 0;
  var taxonomySeries = 0;

  final ipCounts = <String, int>{};
  final brandCounts = <String, int>{};

  for (final series in snap.shelfSeries) {
    if (series.taxonomyIpId != null && series.taxonomyIpId!.isNotEmpty) {
      taxonomySeries++;
      // Taxonomy IDs are already underscore-canonical — use them verbatim so
      // dominantIpId retains the canonical form (e.g. 'the_monsters').
      // canonicalizeStatKey is only for free-text display names below.
      final ipKey = series.taxonomyIpId!;
      if (ipKey.isNotEmpty) ipCounts[ipKey] = (ipCounts[ipKey] ?? 0) + 1;
    } else {
      // Free-text ipName may have capitalisation / spacing variants — normalise
      // so that 'The Monsters' and 'the-monsters' map to the same bucket.
      final fallback = canonicalizeStatKey(series.ipName);
      if (fallback.isNotEmpty) {
        ipCounts[fallback] = (ipCounts[fallback] ?? 0) + 1;
      }
    }
    if (series.taxonomyBrandId != null && series.taxonomyBrandId!.isNotEmpty) {
      // Taxonomy brand IDs are already canonical — use verbatim.
      final brandKey = series.taxonomyBrandId!;
      if (brandKey.isNotEmpty) {
        brandCounts[brandKey] = (brandCounts[brandKey] ?? 0) + 1;
      }
    }

    final resolution = resolveSeriesCompletion(series, snap.figureStates);
    if (resolution.isCompleted) {
      seriesComplete++;
    }

    if (resolution.isNearComplete) nearCompleteSeries++;

    for (final fig in series.figures) {
      if (!fig.isSecret) continue;
      secretSlots++;
      if (snap.trackedOrDefault(fig.id).owned) secretOwned++;
    }
  }

  final seriesCount = snap.shelfSeries.length;
  final taxonomyCoverage = taxonomySeries / seriesCount;
  final confidence = taxonomyCoverage >= 0.75
      ? ShelfInterpretationConfidence.high
      : taxonomyCoverage >= 0.4
          ? ShelfInterpretationConfidence.medium
          : ShelfInterpretationConfidence.low;

  final themes = <String>[];
  if (secretSlots > 0 && secretOwned > 0) themes.add(ShelfEditorialTheme.secrets);
  if (nearCompleteSeries > 0) themes.add(ShelfEditorialTheme.nearComplete);
  if (ipCounts.length >= 2 ||
      ipCounts.values.any((count) => count >= 2)) {
    themes.add(ShelfEditorialTheme.multiUniverse);
  }
  if (seriesComplete == seriesCount && seriesCount > 0) {
    themes.add(ShelfEditorialTheme.harmony);
  }

  final dominantIp = _dominantKey(ipCounts);
  final dominantBrand = _dominantKey(brandCounts);

  final avg = snap.averageCompletionPercent;
  final mood = _resolveShelfMood(
    avgCompletion: avg,
    allComplete: seriesComplete == seriesCount && seriesCount > 0,
    secretOwned: secretOwned,
    secretSlots: secretSlots,
    multiUniverse: themes.contains(ShelfEditorialTheme.multiUniverse),
  );

  return ShelfEmotionalProfile(
    shelfMood: mood,
    interpretationConfidence: confidence,
    dominantBrandId: dominantBrand,
    dominantIpId: dominantIp,
    secretOwnedCount: secretOwned,
    secretSlotCount: secretSlots,
    seriesCompleteCount: seriesComplete,
    editorialThemes: themes,
  );
}

String? _dominantKey(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  String? best;
  var bestCount = 0;
  for (final e in counts.entries) {
    if (e.value > bestCount) {
      bestCount = e.value;
      best = e.key;
    }
  }
  return bestCount >= 2 ? best : null;
}

ShelfMood _resolveShelfMood({
  required int avgCompletion,
  required bool allComplete,
  required int secretOwned,
  required int secretSlots,
  required bool multiUniverse,
}) {
  if (secretSlots > 0 && secretOwned >= 2 && !allComplete) {
    return ShelfMood.chaseHunter;
  }
  if (allComplete) return ShelfMood.settled;
  if (multiUniverse && avgCompletion < 70) return ShelfMood.dreamy;
  if (avgCompletion >= 70) return ShelfMood.settled;
  return ShelfMood.growing;
}
