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

/// Near-complete series ratio for Completionist near path (canonical Regular).
const double kCollectorTypeNearCompleteRatio = kSeriesNearCompleteRatio;

/// Minimum share of shelf series completed / near-complete for Completionist.
///
/// At least three of every five series are finished or in the final push.
const double kCollectorTypeCompletionistShelfRatio = 0.60;

/// Soft cap on completed series counted toward Completionist scale bonus.
const int kCollectorTypeCompletionistCompleteCap = 8;

/// Soft cap on near-complete series counted toward Completionist near path.
const int kCollectorTypeCompletionistNearCap = 6;

/// Dominant **IP** share required for Loyalist (universe loyalty, not brand).
const double kCollectorTypeLoyalistDominanceThreshold = 0.6;

/// Catalog release age (days) treated as “fresh” for Trend Chaser (≈3 months).
const int kCollectorTypeRecentReleaseDays = 90;

/// Minimum share of shelf that must be recent for Trend Chaser (`>` in code).
const double kCollectorTypeTrendRecentRatio = 0.5;

/// Soft cap on recent series counted toward Trend Chaser scale bonus.
const int kCollectorTypeTrendRecentCap = 6;

/// Wishlist share of (owned + wishlist) for Dreamer (`>` in code).
const double kCollectorTypeDreamerWishlistRatio = 0.5;

/// Secret owned / Secret slots hit rate for Hunter and Lucky One.
const double kCollectorTypeSecretHitRate = 0.5;

/// Soft cap on secrets counted toward Hunter scale bonus.
const int kCollectorTypeHunterSecretCap = 8;

/// Max tracked series for Lucky One (early-stage shelf).
///
/// Hunter requires strictly more than this — Lucky One is the prequel.
const int kCollectorTypeCompactSeriesCap = 4;

/// Soft cap on IP spread counted toward Curator scale bonus.
const int kCollectorTypeCuratorIpCap = 8;

/// Minimum distinct taxonomy IPs for Curator.
const int kCollectorTypeCuratorMinIps = 3;

/// Minimum average Regular Completion for Curator (meaningful investment).
const double kCollectorTypeCuratorMinAvgCompletion = 0.5;

/// Custom-series share for Worldbuilder (`>` in code — tie is not dominance).
const double kCollectorTypeWorldbuilderCustomRatio = 0.5;

/// Soft cap on custom figures counted toward Worldbuilder scale bonus.
const int kCollectorTypeWorldbuilderFigureCap = 24;

/// Minimum average Regular Completion for Minimalist (refined, not merely new).
const double kCollectorTypeMinimalistCompletion = 0.70;

/// Max series count for Minimalist path.
const int kCollectorTypeMinimalistSeriesCap = 3;

/// Absolute score epsilon for tie detection before priority order.
const double kCollectorTypeScoreTieEpsilon = 0.01;

// ---------------------------------------------------------------------------
// Collector Type 6.1 — Lucky One → Hunter progression on 6.0 contract
//
// Pipeline: Signals → Behavior eligibility → Strength → Soft-capped scale.
// Presence alone never assigns personality. Journey / Reveal History stay out.
// Wanderer is fallback only (no competitive eligibility gate).
//
// | Archetype     | Defining behavior              | Eligibility                          |
// |---------------|--------------------------------|--------------------------------------|
// | Completionist | Completion defines the shelf   | ≥2 complete/near + ratio ≥ 0.60      |
// | Hunter        | Sustained Secret pursuit       | >4 series + ≥2 Secrets + hit≥0.50    |
// | Lucky One     | Early luck (Hunter prequel)    | !Hunter + ≤4 series + ≥1 + hit≥0.50  |
// | Loyalist      | One IP/universe dominates      | dominantIpShare ≥ 0.60               |
// | Curator       | Multi-universe investment      | !Loyalist + ≥3 IPs + avg ≥ 0.50      |
// | Wanderer      | Identity still forming         | Fallback floor (score 5); never beats specialized |
// | Minimalist    | Small, refined shelf           | ≤3 series + avg ≥ 0.70               |
// | Worldbuilder  | Self-created worlds dominate   | ≥2 custom + customRatio > 0.50       |
// | Dreamer       | Wishlist defines intent        | ≥2 wishlist + wishlistRatio > 0.50   |
// | Trend Chaser  | Recent releases define shelf   | ≥2 recent + recentRatio > 0.50       |
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
///
/// When [catalog] is provided, currently-recent catalog series (90-day window
/// vs [now]) are included so Trend Chaser aging can invalidate without
/// silently rewriting persisted identity.
String computeCollectorTypeSignatureHash(
  CollectionSnapshot snapshot, {
  CatalogSeedBundle? catalog,
  DateTime? now,
}) {
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

  // Always stamp recent-catalog membership (`|r:`) so Trend aging can invalidate
  // and so catalog null (loading) vs empty does not reshape the hash.
  final recentKeys = <String>[];
  if (catalog != null) {
    final asOf = now ?? DateTime.now();
    for (final series in snapshot.shelfSeries) {
      final templateId = series.catalogTemplateId?.trim();
      if (templateId == null || templateId.isEmpty) continue;
      final cat = _catalogSeriesFor(catalog, templateId, null);
      if (cat != null && _isRecentRelease(cat, asOf)) {
        recentKeys.add(templateId);
      }
    }
    recentKeys.sort();
  }
  sb.write('|r:');
  sb.write(recentKeys.join(','));

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
  final stats = buildCollectorTypeStats(snapshot, profile, catalog);
  final signatureHash = computeCollectorTypeSignatureHash(
    snapshot,
    catalog: catalog,
    now: now,
  );
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

CollectorTypeStats buildCollectorTypeStats(
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

  final aggregate = aggregateShelfCompletion(snapshot);

  return CollectorTypeStats(
    totalOwned: snapshot.totalOwnedFigures,
    totalWishlist: snapshot.totalWishlistFigures,
    trackedSeries: snapshot.trackedSeriesCount,
    completedSeriesCount: aggregate.completedSeriesCount,
    masterCompleteSeriesCount: aggregate.masterCompleteSeriesCount,
    masterEligibleSeriesCount: aggregate.masterEligibleSeriesCount,
    completionPercent: aggregate.regularCompletionPercent,
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
  required CollectorTypeStats stats,
  CatalogSeedBundle? catalog,
  Map<String, seed.CatalogSeries>? catalogSeriesById,
  required DateTime now,
}) {
  final scores = {for (final id in CollectorTypeArchetypeId.values) id: 0.0};
  final reasons = <CollectorTypeArchetypeId, CollectorTypeReasonKey>{};

  final seriesCount = snapshot.shelfSeries.length;
  if (seriesCount == 0) return (scores: scores, reasons: reasons);

  final owned = stats.totalOwned;
  final wishlist = stats.totalWishlist;
  final totalTracked = owned + wishlist;
  final wishlistRatio = totalTracked == 0 ? 0.0 : wishlist / totalTracked;
  final secretHitRate =
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
    final resolution =
        resolveSeriesCompletion(series, snapshot.figureStates);
    if (resolution.isNearComplete) {
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

  final completeCount = stats.completedSeriesCount;
  final completedRatio = completeCount / seriesCount;
  final nearRatio = nearComplete / seriesCount;
  final recentRatio = recentCatalogSeries / seriesCount;
  final customRatio = stats.customSeriesRatio;
  final distinctIps = _distinctTaxonomyIpCount(snapshot);
  final dominant = _dominantIpShareDetail(snapshot);
  final loyalistEligible = dominant.share >= kCollectorTypeLoyalistDominanceThreshold &&
      dominant.dominantSeriesCount >= 2;

  // Completionist — completion defines the shelf.
  if (completeCount >= 2 &&
      completedRatio >= kCollectorTypeCompletionistShelfRatio) {
    final cappedComplete =
        math.min(completeCount, kCollectorTypeCompletionistCompleteCap);
    scores[CollectorTypeArchetypeId.completionist] =
        42 + completedRatio * 45 + cappedComplete * 3;
    reasons[CollectorTypeArchetypeId.completionist] =
        CollectorTypeReasonKey.deepCompletion;
  } else if (nearComplete >= 2 &&
      nearRatio >= kCollectorTypeCompletionistShelfRatio) {
    final cappedNear =
        math.min(nearComplete, kCollectorTypeCompletionistNearCap);
    scores[CollectorTypeArchetypeId.completionist] =
        38 + nearRatio * 40 + cappedNear * 3;
    reasons[CollectorTypeArchetypeId.completionist] =
        CollectorTypeReasonKey.nearCompletion;
  }

  // Hunter — sustained Secret pursuit past the early shelf stage.
  // Progression: Lucky One (≤4 series) → Hunter (>4 series).
  final hunterEligible = seriesCount > kCollectorTypeCompactSeriesCap &&
      stats.secretOwned >= 2 &&
      stats.secretSlots > 0 &&
      secretHitRate >= kCollectorTypeSecretHitRate;
  if (hunterEligible) {
    final cappedSecrets =
        math.min(stats.secretOwned, kCollectorTypeHunterSecretCap);
    scores[CollectorTypeArchetypeId.hunter] =
        40 + secretHitRate * 40 + cappedSecrets * 3;
    reasons[CollectorTypeArchetypeId.hunter] =
        CollectorTypeReasonKey.manySecrets;
  }

  // Lucky One — early fortune; Hunter's prequel on a still-small shelf.
  if (!hunterEligible &&
      seriesCount <= kCollectorTypeCompactSeriesCap &&
      stats.secretOwned >= 1 &&
      stats.secretSlots > 0 &&
      secretHitRate >= kCollectorTypeSecretHitRate) {
    scores[CollectorTypeArchetypeId.luckyOne] = 38 + secretHitRate * 40;
    reasons[CollectorTypeArchetypeId.luckyOne] =
        CollectorTypeReasonKey.fortunateSecrets;
  }

  // Loyalist — one IP/universe clearly defines the shelf (not brand).
  // Requires ≥2 series in that IP so “returning” is repeated behavior.
  if (loyalistEligible) {
    scores[CollectorTypeArchetypeId.loyalist] = 35 + dominant.share * 40;
    reasons[CollectorTypeArchetypeId.loyalist] =
        CollectorTypeReasonKey.dominantUniverse;
  }

  // Curator — multi-universe gallery with meaningful investment.
  if (!loyalistEligible &&
      distinctIps >= kCollectorTypeCuratorMinIps &&
      avgCompletion >= kCollectorTypeCuratorMinAvgCompletion) {
    final cappedIp = math.min(distinctIps, kCollectorTypeCuratorIpCap);
    scores[CollectorTypeArchetypeId.curator] =
        28 + cappedIp * 4 + avgCompletion * 22;
    reasons[CollectorTypeArchetypeId.curator] =
        CollectorTypeReasonKey.intentionalSpread;
  }

  // Minimalist — small, refined shelf (no owned-figure cap).
  if (seriesCount <= kCollectorTypeMinimalistSeriesCap &&
      avgCompletion >= kCollectorTypeMinimalistCompletion) {
    scores[CollectorTypeArchetypeId.minimalist] = 42 + avgCompletion * 35;
    reasons[CollectorTypeArchetypeId.minimalist] =
        CollectorTypeReasonKey.compactShelf;
  }

  // Worldbuilder — self-created worlds dominate the shelf.
  if (customSeriesCount >= 2 &&
      customRatio > kCollectorTypeWorldbuilderCustomRatio) {
    final cappedFigures =
        math.min(customFigureCount, kCollectorTypeWorldbuilderFigureCap);
    scores[CollectorTypeArchetypeId.worldbuilder] = 36 +
        customRatio * 40 +
        customSeriesCount * 5 +
        cappedFigures * 1.0 +
        customNotesCount * 4 +
        customCoverCount * 3 +
        customPhotoSeries * 2;
    reasons[CollectorTypeArchetypeId.worldbuilder] =
        CollectorTypeReasonKey.inventedWorlds;
  }

  // Dreamer — wishlist intent defines the tracked collection.
  if (wishlist >= 2 && wishlistRatio > kCollectorTypeDreamerWishlistRatio) {
    scores[CollectorTypeArchetypeId.dreamer] = 38 + wishlistRatio * 40;
    reasons[CollectorTypeArchetypeId.dreamer] =
        CollectorTypeReasonKey.highWishlist;
  }

  // Trend Chaser — recent releases define the shelf (90-day window).
  if (recentCatalogSeries >= 2 &&
      recentRatio > kCollectorTypeTrendRecentRatio) {
    final cappedRecent =
        math.min(recentCatalogSeries, kCollectorTypeTrendRecentCap);
    scores[CollectorTypeArchetypeId.trendChaser] =
        38 + recentRatio * 40 + cappedRecent * 4;
    reasons[CollectorTypeArchetypeId.trendChaser] =
        CollectorTypeReasonKey.freshDrops;
  }

  // Wanderer: soft floor only — present for Still/evolution board checks, never
  // competitive vs specialized bases (≥28). Winner stays fallback when all
  // specialized scores remain 0 (_pickWinner), or when this floor is the max.
  scores[CollectorTypeArchetypeId.wanderer] = 5;

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

/// Dominant IP share of the shelf (universe loyalty).
///
/// Brand is used only for rows that lack a trustworthy taxonomy IP — never to
/// classify a multi-IP POP MART shelf as Loyalist.
///
/// [dominantSeriesCount] is how many series belong to the winning IP (or brand
/// fallback). Loyalist requires this ≥ 2 so “returning” is repeated behavior.
({double share, int dominantSeriesCount}) _dominantIpShareDetail(
  CollectionSnapshot snapshot,
) {
  if (snapshot.shelfSeries.isEmpty) {
    return (share: 0.0, dominantSeriesCount: 0);
  }
  final ipCounts = <String, int>{};
  final brandFallbackCounts = <String, int>{};
  var seriesWithIp = 0;

  for (final s in snapshot.shelfSeries) {
    final ip = s.taxonomyIpId?.trim();
    if (ip != null && ip.isNotEmpty) {
      final key = canonicalizeStatKey(ip);
      if (key.isEmpty) continue;
      ipCounts[key] = (ipCounts[key] ?? 0) + 1;
      seriesWithIp++;
      continue;
    }
    final brand = s.taxonomyBrandId?.trim();
    if (brand != null && brand.isNotEmpty) {
      final key = canonicalizeStatKey(brand);
      if (key.isNotEmpty) {
        brandFallbackCounts[key] = (brandFallbackCounts[key] ?? 0) + 1;
      }
    }
  }

  final n = snapshot.shelfSeries.length;
  var maxIp = 0;
  for (final c in ipCounts.values) {
    if (c > maxIp) maxIp = c;
  }
  final ipShare = maxIp / n;
  if (ipShare >= kCollectorTypeLoyalistDominanceThreshold) {
    return (share: ipShare, dominantSeriesCount: maxIp);
  }

  // Brand fallback only when most rows lack IP (cannot form an IP story).
  if (seriesWithIp / n > 0.5) {
    return (share: ipShare, dominantSeriesCount: maxIp);
  }
  var maxBrand = 0;
  for (final c in brandFallbackCounts.values) {
    if (c > maxBrand) maxBrand = c;
  }
  return (share: maxBrand / n, dominantSeriesCount: maxBrand);
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

/// Distinct trustworthy taxonomy IP identities on the current shelf.
int _distinctTaxonomyIpCount(CollectionSnapshot snapshot) {
  final keys = <String>{};
  for (final series in snapshot.shelfSeries) {
    final taxonomyIp = series.taxonomyIpId?.trim();
    if (taxonomyIp != null && taxonomyIp.isNotEmpty) {
      keys.add(canonicalizeStatKey(taxonomyIp));
    }
  }
  return keys.length;
}
