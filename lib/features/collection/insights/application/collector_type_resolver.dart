import 'dart:math' as math;

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as seed;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_resolve.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_stat_keys.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';

/// Minimum analyzing hold duration (ms) —mirrored by view model.
const int collectorTypeAnalyzingHoldMs = 1400;

// --- Scoring policy thresholds (bump [kCollectorTypeResolverVersion] when these change) ---

/// Series owned/slots ratio treated as “near complete” for Completionist.
const double kCollectorTypeNearCompleteRatio = 0.85;

/// Minimum share of shelf series that are finished for Completionist deep path.
///
/// Completing two series on a twenty-series shelf is evidence, not identity.
const double kCollectorTypeCompletionistFinishRatio = 0.4;

/// Soft cap on completed series counted toward Completionist scale bonus.
const int kCollectorTypeCompletionistCompleteCap = 8;

/// Soft cap on near-complete series counted toward Completionist near path.
const int kCollectorTypeCompletionistNearCap = 6;

/// Dominant brand/IP share required to qualify as Loyalist.
const double kCollectorTypeLoyalistDominanceThreshold = 0.6;

/// Catalog release age (days) treated as “fresh” for Trend Chaser.
const int kCollectorTypeRecentReleaseDays = 180;

/// Minimum share of shelf series that are recent catalog drops for Trend Chaser.
///
/// Owning two fresh series on a mostly-old shelf is evidence, not chasing.
const double kCollectorTypeTrendRecentRatio = 0.4;

/// Soft cap on recent series counted toward Trend Chaser scale bonus.
const int kCollectorTypeTrendRecentCap = 6;

/// Wishlist share of (owned + wishlist) to qualify as Dreamer.
const double kCollectorTypeDreamerWishlistRatio = 0.45;

/// Secret owned/slots density required for Hunter (hunting defines the shelf).
const double kCollectorTypeHunterSecretDensity = 0.35;

/// Soft cap on secrets counted toward Hunter scale bonus.
const int kCollectorTypeHunterSecretCap = 8;

/// Secret owned/slots ratio + compact shelf for Lucky One.
const double kCollectorTypeLuckyOneSecretRatio = 0.5;

/// Max tracked series for Lucky One compact path.
const int kCollectorTypeCompactSeriesCap = 4;

/// Soft caps for Curator spread amplification (after multi-world eligibility).
const int kCollectorTypeCuratorBrandCap = 5;

/// Soft cap on IP spread counted toward Curator scale bonus.
const int kCollectorTypeCuratorIpCap = 8;

/// Minimum custom-series share of the shelf to qualify as Worldbuilder.
///
/// Authorship gate: catalog-only shelves never qualify. In the product, series
/// notes / covers / local photos exist only on custom series — they cannot
/// appear on official catalog rows through the UI.
const double kCollectorTypeWorldbuilderCustomRatio = 0.3;

/// Soft cap on custom figures counted toward Worldbuilder score.
const int kCollectorTypeWorldbuilderFigureCap = 24;

/// Minimum average completion for Minimalist (with small shelf).
const double kCollectorTypeMinimalistCompletion = 0.75;

/// Max series count for Minimalist path.
const int kCollectorTypeMinimalistSeriesCap = 3;

/// Max owned figures for Minimalist path.
const int kCollectorTypeMinimalistOwnedCap = 12;

/// Absolute score epsilon for tie detection before priority order.
const double kCollectorTypeScoreTieEpsilon = 0.01;

// ---------------------------------------------------------------------------
// Collector Type 5.0 — behavior inference (Identity = defining shelf behavior)
//
// Pipeline: Signals → Behavior eligibility → Strength → Soft-capped scale.
// Presence alone never assigns personality. Journey / Reveal History stay out.
//
// | Archetype     | Defining behavior            | Eligibility (then strength)          |
// |---------------|------------------------------|--------------------------------------|
// | Completionist | Finishing defines the shelf  | finishRatio / nearRatio + avg        |
// | Hunter        | Hunting rarity defines shelf | secret density (+ theme path)        |
// | Lucky One     | Fortune on a compact shelf   | ratio + compact; not when Hunter     |
// | Loyalist      | One universe dominates       | dominantShare ≥ 0.6                  |
// | Curator       | Multi-world gallery          | spread + not Loyalist-dominant       |
// | Wanderer      | Curious unfinished spread    | brands + low avg (+ empty fallback)  |
// | Minimalist    | Small finished shelf         | size caps + high avg                 |
// | Worldbuilder  | Authorship of custom worlds  | customRatio ≥ 0.3                    |
// | Dreamer       | Wishlist-forward collecting  | wishlistRatio ≥ 0.45                 |
// | Trend Chaser  | Chasing fresh drops          | recentRatio ≥ 0.4 (+ recent ≥ 2)     |
// ---------------------------------------------------------------------------

/// Confidence when winner score is non-positive (empty / fallback).
const double kCollectorTypeConfidenceEmptyFloor = 0.25;

/// Confidence when winner does not lead the runner-up.
const double kCollectorTypeConfidenceTiedFloor = 0.35;

/// Minimum clamped lead-margin confidence.
const double kCollectorTypeConfidenceMin = 0.05;

/// Computes a stable shelf signature for era-shift / needs-reveal detection.
///
/// Must change when shelf **composition** changes (tracked series, brand mix,
/// IP mix), not only when figure ownership flips. Brand Distribution and other
/// reveal stats are frozen on [CollectorTypeIdentity] until re-reveal; if this
/// hash misses series adds, Insights keeps showing stale breakdowns with no
/// Reveal again affordance.
String computeCollectorTypeSignatureHash(CollectionSnapshot snapshot) {
  final owned = <String>[];
  final wishlist = <String>[];
  for (final e in snapshot.figureStates.entries) {
    if (e.value.owned) owned.add(e.key);
    if (e.value.wishlist) wishlist.add(e.key);
  }
  owned.sort();
  wishlist.sort();

  var customSeries = 0;
  final brandCounts = <String, int>{};
  final ipCounts = <String, int>{};
  final seriesKeys = <String>[];
  for (final series in snapshot.shelfSeries) {
    if (series.isCustomLocal) customSeries++;
    final templateId = series.catalogTemplateId?.trim();
    seriesKeys.add(
      (templateId != null && templateId.isNotEmpty) ? templateId : series.id,
    );
    final brand = series.taxonomyBrandId?.trim();
    if (brand != null && brand.isNotEmpty) {
      final key = canonicalizeStatKey(brand);
      if (key.isNotEmpty) brandCounts[key] = (brandCounts[key] ?? 0) + 1;
    }
    final ip = series.taxonomyIpId?.trim();
    if (ip != null && ip.isNotEmpty) {
      final key = canonicalizeStatKey(ip);
      if (key.isNotEmpty) ipCounts[key] = (ipCounts[key] ?? 0) + 1;
    }
  }
  seriesKeys.sort();

  final sb = StringBuffer()
    ..write('o:')
    ..write(owned.join(','))
    ..write('|w:')
    ..write(wishlist.join(','))
    ..write('|c:')
    ..write(customSeries)
    ..write('|s:')
    ..write(seriesKeys.join(','))
    ..write('|b:')
    ..write(_sortedCountPairs(brandCounts))
    ..write('|i:')
    ..write(_sortedCountPairs(ipCounts));
  return sb.toString();
}

String _sortedCountPairs(Map<String, int> counts) {
  if (counts.isEmpty) return '';
  final keys = counts.keys.toList()..sort();
  final parts = <String>[];
  for (final k in keys) {
    parts.add('$k=${counts[k]}');
  }
  return parts.join(',');
}

/// Rule-based collector identity resolution (pure, no Riverpod).
///
/// Returns a [CollectorTypeResolution] — the shared domain outcome for Reveal,
/// Hero, and future History. Callers apply [shouldEvolve] before persisting.
///
/// **Signal ownership (2.0):** scores from current shelf, collection stats,
/// emotional profile, and catalog metadata attached to shelf items only.
/// Does not read Collector Journey memory or Reveal History.
CollectorTypeResolution resolveCollectorType({
  required CollectionSnapshot snapshot,
  required ShelfEmotionalProfile profile,
  CatalogSeedBundle? catalog,
  DateTime? revealedAt,
}) {
  final now = revealedAt ?? DateTime.now();
  final catalogSeriesById = catalog == null
      ? null
      : {for (final s in catalog.series) s.id: s};
  final stats = _buildStats(snapshot, profile, catalog);
  final signatureHash = computeCollectorTypeSignatureHash(snapshot);
  final emptyScores = {
    for (final id in CollectorTypeArchetypeId.values) id: 0.0,
  };

  if (snapshot.shelfSeries.isEmpty ||
      (profile.interpretationConfidence == ShelfInterpretationConfidence.low &&
          snapshot.totalOwnedFigures == 0)) {
    return CollectorTypeResolution(
      archetypeId: CollectorTypeArchetypeId.wanderer,
      score: 0,
      confidence: kCollectorTypeConfidenceEmptyFloor,
      reasonKey: CollectorTypeReasonKey.stillUnfolding,
      signatureHash: signatureHash,
      stats: stats,
      scores: emptyScores,
      reasons: const {},
    );
  }

  final scored = _scoreArchetypes(
    snapshot: snapshot,
    profile: profile,
    stats: stats,
    catalog: catalog,
    catalogSeriesById: catalogSeriesById,
    now: now,
  );

  final picked = _pickWinner(scored.scores, scored.reasons);
  return CollectorTypeResolution(
    archetypeId: picked.id,
    score: picked.score,
    confidence: _confidence(winner: picked.score, runnerUp: picked.runnerUp),
    reasonKey: picked.reasonKey,
    signatureHash: signatureHash,
    stats: stats,
    scores: scored.scores,
    reasons: scored.reasons,
  );
}

double _confidence({required double winner, required double runnerUp}) {
  if (winner <= 0) return kCollectorTypeConfidenceEmptyFloor;
  final gap = winner - runnerUp;
  if (gap <= 0) return kCollectorTypeConfidenceTiedFloor;
  return (gap / winner).clamp(kCollectorTypeConfidenceMin, 1.0);
}

CollectorTypeStats _buildStats(
  CollectionSnapshot snapshot,
  ShelfEmotionalProfile profile,
  CatalogSeedBundle? catalog,
) {
  final brandEntries = <({String displayLabel, String rawKey})>[];
  final seriesOwned = <String, int>{};

  for (final series in snapshot.shelfSeries) {
    final rawKey = series.taxonomyBrandId?.trim() ?? series.brand.trim();
    if (rawKey.isNotEmpty) {
      final display =
          series.brand.trim().isNotEmpty ? series.brand.trim() : rawKey;
      brandEntries.add((displayLabel: display, rawKey: rawKey));
    }
    final progress = progressForSeries(series, snapshot.figureStates);
    if (progress.owned > 0) {
      seriesOwned[series.name] = progress.owned;
    }
  }

  final topSeries = seriesOwned.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topNames = topSeries.take(3).map((e) => e.key).toList();

  var customCount = 0;
  for (final s in snapshot.shelfSeries) {
    if (s.isCustomLocal) customCount++;
  }
  final customRatio = snapshot.shelfSeries.isEmpty
      ? 0.0
      : customCount / snapshot.shelfSeries.length;

  final brandBreakdown = aggregateBrandBreakdownByCanonicalKey(brandEntries);

  final (completedSeriesCount, masterCompleteSeriesCount) =
      countShelfCompletionTiers(snapshot);

  return CollectorTypeStats(
    totalOwned: snapshot.totalOwnedFigures,
    totalWishlist: snapshot.totalWishlistFigures,
    trackedSeries: snapshot.trackedSeriesCount,
    completedSeriesCount: completedSeriesCount,
    masterCompleteSeriesCount: masterCompleteSeriesCount,
    completionPercent: snapshot.averageCompletionPercent,
    secretOwned: profile.secretOwnedCount,
    secretSlots: profile.secretSlotCount,
    brandBreakdown: brandBreakdown,
    topSeries: topNames,
    customSeriesRatio: customRatio,
  );
}

({
  Map<CollectorTypeArchetypeId, double> scores,
  Map<CollectorTypeArchetypeId, CollectorTypeReasonKey> reasons,
}) _scoreArchetypes({
  required CollectionSnapshot snapshot,
  required ShelfEmotionalProfile profile,
  required CollectorTypeStats stats,
  CatalogSeedBundle? catalog,
  Map<String, seed.CatalogSeries>? catalogSeriesById,
  required DateTime now,
}) {
  final scores = {for (final id in CollectorTypeArchetypeId.values) id: 0.0};
  final reasons = <CollectorTypeArchetypeId, CollectorTypeReasonKey>{};

  final seriesCount = snapshot.shelfSeries.length;
  final owned = stats.totalOwned;
  final wishlist = stats.totalWishlist;
  final totalTracked = owned + wishlist;
  final wishlistRatio = totalTracked == 0 ? 0.0 : wishlist / totalTracked;
  final secretOwnedRatio =
      stats.secretSlots == 0 ? 0.0 : stats.secretOwned / stats.secretSlots;
  final avgCompletion = stats.completionPercent / 100.0;

  var nearComplete = 0;
  var recentCatalogSeries = 0;
  var customSeriesCount = 0;
  var customFigureCount = 0;
  var customNotesCount = 0;
  var customCoverCount = 0;
  var customPhotoSeries = 0;

  for (final series in snapshot.shelfSeries) {
    final progress = progressForSeries(series, snapshot.figureStates);
    final total = series.figureCount;
    if (total > 0 &&
        progress.owned < total &&
        progress.owned / total >= kCollectorTypeNearCompleteRatio) {
      nearComplete++;
    }
    if (catalog != null && series.catalogTemplateId != null) {
      final cat = _catalogSeriesFor(
        catalog,
        series.catalogTemplateId!,
        catalogSeriesById,
      );
      if (cat != null && _isRecentRelease(cat, now)) recentCatalogSeries++;
    }

    // Worldbuilder authorship signals — custom rows only.
    if (!series.isCustomLocal) continue;
    customSeriesCount++;
    customFigureCount += series.figures.length;
    if (series.notes != null && series.notes!.trim().isNotEmpty) {
      customNotesCount++;
    }
    final hasCover = series.customCoverImageUri != null &&
        series.customCoverImageUri!.trim().isNotEmpty;
    if (hasCover) customCoverCount++;
    var hasFigurePhoto = false;
    for (final fig in series.figures) {
      if (fig.localImageUri != null && fig.localImageUri!.trim().isNotEmpty) {
        hasFigurePhoto = true;
        break;
      }
    }
    if (hasCover || hasFigurePhoto) customPhotoSeries++;
  }

  final brandSpread = stats.brandBreakdown.length;
  final shelfIpSpread = _shelfIpSpread(snapshot);
  final completeCount = profile.seriesCompleteCount;
  final finishRatio =
      seriesCount == 0 ? 0.0 : completeCount / seriesCount;
  final nearRatio = seriesCount == 0 ? 0.0 : nearComplete / seriesCount;
  final recentRatio =
      seriesCount == 0 ? 0.0 : recentCatalogSeries / seriesCount;
  final dominantShare = _dominantShare(snapshot, profile);
  final loyalistDominant =
      dominantShare >= kCollectorTypeLoyalistDominanceThreshold &&
          (profile.dominantBrandId != null || profile.dominantIpId != null);

  // Completionist — finishing defines the shelf (not merely owning finishes).
  if (completeCount >= 2 &&
      avgCompletion >= 0.7 &&
      finishRatio >= kCollectorTypeCompletionistFinishRatio) {
    final cappedComplete =
        math.min(completeCount, kCollectorTypeCompletionistCompleteCap);
    scores[CollectorTypeArchetypeId.completionist] = 35 +
        finishRatio * 35 +
        avgCompletion * 25 +
        cappedComplete * 5;
    reasons[CollectorTypeArchetypeId.completionist] =
        CollectorTypeReasonKey.deepCompletion;
  } else if (nearComplete >= 2 &&
      nearRatio >= kCollectorTypeCompletionistFinishRatio) {
    final cappedNear =
        math.min(nearComplete, kCollectorTypeCompletionistNearCap);
    scores[CollectorTypeArchetypeId.completionist] =
        25 + nearRatio * 25 + cappedNear * 5;
    reasons[CollectorTypeArchetypeId.completionist] =
        CollectorTypeReasonKey.nearCompletion;
  }

  // Hunter — hunting rarity defines the shelf (density, not presence).
  final hunterEligible = stats.secretOwned >= 1 &&
      secretOwnedRatio >= kCollectorTypeHunterSecretDensity &&
      (stats.secretOwned >= 2 || profile.themeIncludes('secrets'));
  if (hunterEligible) {
    final cappedSecrets =
        math.min(stats.secretOwned, kCollectorTypeHunterSecretCap);
    scores[CollectorTypeArchetypeId.hunter] =
        30 + secretOwnedRatio * 40 + cappedSecrets * 5;
    reasons[CollectorTypeArchetypeId.hunter] =
        CollectorTypeReasonKey.manySecrets;
  }

  // Lucky One — compact fortune; mutually exclusive with Hunter.
  if (!hunterEligible &&
      stats.secretOwned >= 1 &&
      secretOwnedRatio >= kCollectorTypeLuckyOneSecretRatio &&
      seriesCount <= kCollectorTypeCompactSeriesCap) {
    scores[CollectorTypeArchetypeId.luckyOne] = 30 + secretOwnedRatio * 40;
    reasons[CollectorTypeArchetypeId.luckyOne] =
        CollectorTypeReasonKey.fortunateSecrets;
  }

  // Loyalist — one universe dominates composition (share gate).
  if (loyalistDominant) {
    scores[CollectorTypeArchetypeId.loyalist] = 35 + dominantShare * 40;
    reasons[CollectorTypeArchetypeId.loyalist] =
        CollectorTypeReasonKey.dominantUniverse;
  }

  // Curator — multi-world gallery without Loyalist-level focus.
  // Presence of 2 IPs is evidence; defining = spread without a dominant world.
  if (!loyalistDominant && (brandSpread >= 2 || shelfIpSpread >= 2)) {
    final cappedBrand =
        math.min(brandSpread, kCollectorTypeCuratorBrandCap);
    final cappedIp = math.min(shelfIpSpread, kCollectorTypeCuratorIpCap);
    scores[CollectorTypeArchetypeId.curator] =
        25 + cappedBrand * 8 + cappedIp * 5;
    reasons[CollectorTypeArchetypeId.curator] =
        CollectorTypeReasonKey.intentionalSpread;
  }

  // Wanderer — curious unfinished spread (composition + low completion).
  if (brandSpread >= 2 && avgCompletion < 0.5 && seriesCount >= 2) {
    scores[CollectorTypeArchetypeId.wanderer] =
        20 + brandSpread * 6 + (1 - avgCompletion) * 20;
    reasons[CollectorTypeArchetypeId.wanderer] =
        CollectorTypeReasonKey.curiousSpread;
  }

  // Minimalist — small finished shelf (state).
  if (seriesCount <= kCollectorTypeMinimalistSeriesCap &&
      owned <= kCollectorTypeMinimalistOwnedCap &&
      avgCompletion >= kCollectorTypeMinimalistCompletion) {
    scores[CollectorTypeArchetypeId.minimalist] = 35 + avgCompletion * 25;
    reasons[CollectorTypeArchetypeId.minimalist] =
        CollectorTypeReasonKey.compactShelf;
  }

  // Worldbuilder — authorship: custom ratio defines the shelf.
  final customRatio = stats.customSeriesRatio;
  if (customSeriesCount >= 1 &&
      customRatio >= kCollectorTypeWorldbuilderCustomRatio) {
    final cappedFigures =
        math.min(customFigureCount, kCollectorTypeWorldbuilderFigureCap);
    scores[CollectorTypeArchetypeId.worldbuilder] = 20 +
        customRatio * 55 +
        customSeriesCount * 10 +
        cappedFigures * 1.25 +
        customNotesCount * 5 +
        customCoverCount * 4 +
        customPhotoSeries * 2;
    reasons[CollectorTypeArchetypeId.worldbuilder] =
        CollectorTypeReasonKey.inventedWorlds;
  }

  // Dreamer — wishlist-forward collecting (ratio).
  if (wishlistRatio >= kCollectorTypeDreamerWishlistRatio && wishlist >= 2) {
    scores[CollectorTypeArchetypeId.dreamer] = 30 + wishlistRatio * 35;
    reasons[CollectorTypeArchetypeId.dreamer] =
        CollectorTypeReasonKey.highWishlist;
  }

  // Trend Chaser — chasing fresh drops defines the shelf (recentRatio).
  if (recentCatalogSeries >= 2 &&
      recentRatio >= kCollectorTypeTrendRecentRatio) {
    final cappedRecent =
        math.min(recentCatalogSeries, kCollectorTypeTrendRecentCap);
    scores[CollectorTypeArchetypeId.trendChaser] =
        35 + recentRatio * 45 + cappedRecent * 6;
    reasons[CollectorTypeArchetypeId.trendChaser] =
        CollectorTypeReasonKey.freshDrops;
  }

  return (scores: scores, reasons: reasons);
}

({
  CollectorTypeArchetypeId id,
  double score,
  double runnerUp,
  CollectorTypeReasonKey reasonKey,
}) _pickWinner(
  Map<CollectorTypeArchetypeId, double> scores,
  Map<CollectorTypeArchetypeId, CollectorTypeReasonKey> reasons,
) {
  var bestScore = -1.0;
  CollectorTypeArchetypeId? bestId;
  for (final e in scores.entries) {
    if (e.value > bestScore) {
      bestScore = e.value;
      bestId = e.key;
    }
  }
  if (bestId == null || bestScore <= 0) {
    return (
      id: CollectorTypeArchetypeId.wanderer,
      score: 0,
      runnerUp: 0,
      reasonKey: CollectorTypeReasonKey.stillUnfolding,
    );
  }

  final tied = scores.entries
      .where((e) => (e.value - bestScore).abs() < kCollectorTypeScoreTieEpsilon)
      .map((e) => e.key)
      .toSet();
  var winner = bestId;
  if (tied.length > 1) {
    for (final id in CollectorTypeArchetypes.tieBreakPriority) {
      if (tied.contains(id)) {
        winner = id;
        break;
      }
    }
  }

  var runnerUp = 0.0;
  for (final e in scores.entries) {
    if (e.key == winner) continue;
    if (e.value > runnerUp) runnerUp = e.value;
  }

  return (
    id: winner,
    score: scores[winner] ?? bestScore,
    runnerUp: runnerUp,
    reasonKey: reasons[winner] ??
        canonicalReasonKeyForArchetype(winner),
  );
}

double _dominantShare(
  CollectionSnapshot snapshot,
  ShelfEmotionalProfile profile,
) {
  if (snapshot.shelfSeries.isEmpty) return 0;
  final targetBrand = profile.dominantBrandId == null
      ? null
      : canonicalizeStatKey(profile.dominantBrandId!);
  final targetIp = profile.dominantIpId == null
      ? null
      : canonicalizeStatKey(profile.dominantIpId!);
  var match = 0;
  for (final s in snapshot.shelfSeries) {
    final brand = s.taxonomyBrandId?.trim();
    if (targetBrand != null &&
        brand != null &&
        brand.isNotEmpty &&
        canonicalizeStatKey(brand) == targetBrand) {
      match++;
    } else {
      final ip = s.taxonomyIpId?.trim();
      if (targetIp != null &&
          ip != null &&
          ip.isNotEmpty &&
          canonicalizeStatKey(ip) == targetIp) {
        match++;
      }
    }
  }
  return match / snapshot.shelfSeries.length;
}

seed.CatalogSeries? _catalogSeriesFor(
  CatalogSeedBundle catalog,
  String id,
  Map<String, seed.CatalogSeries>? catalogSeriesById,
) {
  if (catalogSeriesById != null) return catalogSeriesById[id];
  for (final s in catalog.series) {
    if (s.id == id) return s;
  }
  return null;
}

bool _isRecentRelease(seed.CatalogSeries series, DateTime now) {
  final raw = series.releaseDate;
  if (raw == null || raw.isEmpty) return false;
  try {
    final parts = raw.split('-');
    if (parts.length < 3) return false;
    final released = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return now.difference(released).inDays <= kCollectorTypeRecentReleaseDays;
  } catch (_) {
    return false;
  }
}

int _shelfIpSpread(CollectionSnapshot snapshot) {
  final keys = <String>{};
  for (final series in snapshot.shelfSeries) {
    final taxonomyIp = series.taxonomyIpId?.trim();
    if (taxonomyIp != null && taxonomyIp.isNotEmpty) {
      keys.add(canonicalizeStatKey(taxonomyIp));
      continue;
    }
    final fallback = canonicalizeStatKey(series.ipName);
    if (fallback.isNotEmpty) keys.add(fallback);
  }
  return keys.length;
}
