import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as seed;
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
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

/// Dominant brand/IP share required to qualify as Loyalist.
const double kCollectorTypeLoyalistDominanceThreshold = 0.6;

/// Catalog release age (days) treated as “fresh” for Trend Chaser.
const int kCollectorTypeRecentReleaseDays = 180;

/// Wishlist share of (owned + wishlist) to qualify as Dreamer.
const double kCollectorTypeDreamerWishlistRatio = 0.45;

/// Secret owned/slots ratio + compact shelf for Lucky One.
const double kCollectorTypeLuckyOneSecretRatio = 0.5;

/// Max tracked series for Lucky One / single-drop Trend Chaser paths.
const int kCollectorTypeCompactSeriesCap = 4;

/// Custom-series share that contributes to Stylist.
const double kCollectorTypeStylistCustomRatio = 0.3;

/// Minimum average completion for Minimalist (with small shelf).
const double kCollectorTypeMinimalistCompletion = 0.75;

/// Max series count for Minimalist path.
const int kCollectorTypeMinimalistSeriesCap = 3;

/// Max owned figures for Minimalist path.
const int kCollectorTypeMinimalistOwnedCap = 12;

/// Days since first series add that boosts Archivist.
const int kCollectorTypeArchivistTenureDays = 90;

/// Absolute score epsilon for tie detection before priority order.
const double kCollectorTypeScoreTieEpsilon = 0.01;

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
CollectorTypeResolution resolveCollectorType({
  required CollectionSnapshot snapshot,
  required ShelfEmotionalProfile profile,
  CatalogSeedBundle? catalog,
  CollectionMemoryData? memory,
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
    memory: memory,
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

  return CollectorTypeStats(
    totalOwned: snapshot.totalOwnedFigures,
    totalWishlist: snapshot.totalWishlistFigures,
    trackedSeries: snapshot.trackedSeriesCount,
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
  CollectionMemoryData? memory,
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
  var notesCount = 0;
  var photoSeries = 0;
  var recentCatalogSeries = 0;

  for (final series in snapshot.shelfSeries) {
    final progress = progressForSeries(series, snapshot.figureStates);
    final total = series.figureCount;
    if (total > 0 &&
        progress.owned < total &&
        progress.owned / total >= kCollectorTypeNearCompleteRatio) {
      nearComplete++;
    }
    if (series.notes != null && series.notes!.trim().isNotEmpty) notesCount++;
    if (series.customCoverImageUri != null &&
        series.customCoverImageUri!.trim().isNotEmpty) {
      photoSeries++;
    }
    for (final fig in series.figures) {
      if (fig.localImageUri != null && fig.localImageUri!.trim().isNotEmpty) {
        photoSeries++;
        break;
      }
    }
    if (catalog != null && series.catalogTemplateId != null) {
      final cat = _catalogSeriesFor(
        catalog,
        series.catalogTemplateId!,
        catalogSeriesById,
      );
      if (cat != null && _isRecentRelease(cat, now)) recentCatalogSeries++;
    }
  }

  final brandSpread = stats.brandBreakdown.length;
  final shelfIpSpread = _shelfIpSpread(snapshot);
  final ipDepthKeys = memory?.ipSeriesDepth.length ?? 0;

  if (profile.seriesCompleteCount >= 2 && avgCompletion >= 0.7) {
    scores[CollectorTypeArchetypeId.completionist] =
        40 + profile.seriesCompleteCount * 12 + avgCompletion * 30;
    reasons[CollectorTypeArchetypeId.completionist] =
        CollectorTypeReasonKey.deepCompletion;
  } else if (nearComplete >= 2) {
    scores[CollectorTypeArchetypeId.completionist] = 25 + nearComplete * 8;
    reasons[CollectorTypeArchetypeId.completionist] =
        CollectorTypeReasonKey.nearCompletion;
  }

  if (stats.secretOwned >= 2) {
    scores[CollectorTypeArchetypeId.hunter] =
        35 + stats.secretOwned * 10 + secretOwnedRatio * 25;
    reasons[CollectorTypeArchetypeId.hunter] =
        CollectorTypeReasonKey.manySecrets;
  } else if (profile.themeIncludes('secrets') && stats.secretOwned >= 1) {
    scores[CollectorTypeArchetypeId.hunter] = 20 + secretOwnedRatio * 20;
    reasons[CollectorTypeArchetypeId.hunter] =
        CollectorTypeReasonKey.manySecrets;
  }

  if (stats.secretOwned >= 1 &&
      secretOwnedRatio >= kCollectorTypeLuckyOneSecretRatio &&
      seriesCount <= kCollectorTypeCompactSeriesCap) {
    scores[CollectorTypeArchetypeId.luckyOne] = 30 + secretOwnedRatio * 40;
    reasons[CollectorTypeArchetypeId.luckyOne] =
        CollectorTypeReasonKey.fortunateSecrets;
  }

  if (profile.dominantBrandId != null || profile.dominantIpId != null) {
    final dominantShare = _dominantShare(snapshot, profile);
    if (dominantShare >= kCollectorTypeLoyalistDominanceThreshold) {
      scores[CollectorTypeArchetypeId.loyalist] = 35 + dominantShare * 40;
      reasons[CollectorTypeArchetypeId.loyalist] =
          CollectorTypeReasonKey.dominantUniverse;
    }
  }

  if (brandSpread >= 2 || shelfIpSpread >= 2) {
    scores[CollectorTypeArchetypeId.curator] =
        25 + brandSpread * 8 + ipDepthKeys * 5;
    reasons[CollectorTypeArchetypeId.curator] =
        CollectorTypeReasonKey.intentionalSpread;
  }

  if (brandSpread >= 2 && avgCompletion < 0.5 && seriesCount >= 2) {
    scores[CollectorTypeArchetypeId.wanderer] =
        20 + brandSpread * 6 + (1 - avgCompletion) * 20;
    reasons[CollectorTypeArchetypeId.wanderer] =
        CollectorTypeReasonKey.curiousSpread;
  }

  if (seriesCount <= kCollectorTypeMinimalistSeriesCap &&
      owned <= kCollectorTypeMinimalistOwnedCap &&
      avgCompletion >= kCollectorTypeMinimalistCompletion) {
    scores[CollectorTypeArchetypeId.minimalist] = 35 + avgCompletion * 25;
    reasons[CollectorTypeArchetypeId.minimalist] =
        CollectorTypeReasonKey.compactShelf;
  }

  if (notesCount >= 1 || photoSeries >= 2) {
    scores[CollectorTypeArchetypeId.archivist] =
        20 + notesCount * 10 + photoSeries * 8;
    reasons[CollectorTypeArchetypeId.archivist] =
        CollectorTypeReasonKey.livingArchive;
  }
  final firstAdded = memory?.firstSeriesAddedAt;
  if (firstAdded != null &&
      now.difference(firstAdded).inDays >= kCollectorTypeArchivistTenureDays) {
    scores[CollectorTypeArchetypeId.archivist] =
        (scores[CollectorTypeArchetypeId.archivist] ?? 0) + 15;
    reasons.putIfAbsent(
      CollectorTypeArchetypeId.archivist,
      () => CollectorTypeReasonKey.livingArchive,
    );
  }

  if (stats.customSeriesRatio >= kCollectorTypeStylistCustomRatio ||
      photoSeries >= 2) {
    scores[CollectorTypeArchetypeId.stylist] =
        25 + stats.customSeriesRatio * 40 + photoSeries * 6;
    reasons[CollectorTypeArchetypeId.stylist] =
        CollectorTypeReasonKey.composedShelf;
  }

  if (wishlistRatio >= kCollectorTypeDreamerWishlistRatio && wishlist >= 2) {
    scores[CollectorTypeArchetypeId.dreamer] = 30 + wishlistRatio * 35;
    reasons[CollectorTypeArchetypeId.dreamer] =
        CollectorTypeReasonKey.highWishlist;
  }

  if (wishlist > owned && wishlist >= 3) {
    scores[CollectorTypeArchetypeId.daydreamCollector] =
        45 + (wishlist - owned) * 6 + wishlistRatio * 20;
    reasons[CollectorTypeArchetypeId.daydreamCollector] =
        CollectorTypeReasonKey.wishlistDominates;
  }

  if (recentCatalogSeries >= 2) {
    scores[CollectorTypeArchetypeId.trendChaser] =
        50 + recentCatalogSeries * 14;
    reasons[CollectorTypeArchetypeId.trendChaser] =
        CollectorTypeReasonKey.freshDrops;
  } else if (recentCatalogSeries == 1 &&
      seriesCount <= kCollectorTypeCompactSeriesCap) {
    scores[CollectorTypeArchetypeId.trendChaser] = 28;
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
