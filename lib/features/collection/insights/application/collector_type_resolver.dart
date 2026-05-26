import 'dart:convert';

import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as seed;
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_stat_keys.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';

/// Minimum analyzing hold duration (ms) — mirrored by view model.
const int collectorTypeAnalyzingHoldMs = 1400;

/// Computes a stable shelf signature for era-shift detection.
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
  for (final series in snapshot.shelfSeries) {
    if (series.isCustomLocal) customSeries++;
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

  final dominantBrand = _dominantKey(brandCounts);
  final dominantIp = _dominantKey(ipCounts);

  final payload = {
    'owned': owned,
    'wishlist': wishlist,
    'customSeries': customSeries,
    'dominantBrand': dominantBrand,
    'dominantIp': dominantIp,
  };
  return base64Url.encode(utf8.encode(jsonEncode(payload)));
}

/// Rule-based collector identity resolution (pure, no Riverpod).
CollectorTypeIdentity resolveCollectorType({
  required CollectionSnapshot snapshot,
  required ShelfEmotionalProfile profile,
  CatalogSeedBundle? catalog,
  CollectionMemoryData? memory,
  DateTime? revealedAt,
}) {
  final now = revealedAt ?? DateTime.now();
  final stats = _buildStats(snapshot, profile, catalog);
  final signatureHash = computeCollectorTypeSignatureHash(snapshot);

  if (snapshot.shelfSeries.isEmpty ||
      (profile.interpretationConfidence == ShelfInterpretationConfidence.low &&
          snapshot.totalOwnedFigures == 0)) {
    return CollectorTypeIdentity(
      archetypeId: CollectorTypeArchetypeId.wanderer,
      revealedAt: now,
      signatureHash: signatureHash,
      stats: stats,
    );
  }

  final scores = _scoreArchetypes(
    snapshot: snapshot,
    profile: profile,
    stats: stats,
    catalog: catalog,
    memory: memory,
    now: now,
  );

  final winner = _pickWinner(scores);
  return CollectorTypeIdentity(
    archetypeId: winner,
    revealedAt: now,
    signatureHash: signatureHash,
    stats: stats,
  );
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
      final display = series.brand.trim().isNotEmpty
          ? series.brand.trim()
          : rawKey;
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

Map<CollectorTypeArchetypeId, double> _scoreArchetypes({
  required CollectionSnapshot snapshot,
  required ShelfEmotionalProfile profile,
  required CollectorTypeStats stats,
  CatalogSeedBundle? catalog,
  CollectionMemoryData? memory,
  required DateTime now,
}) {
  final scores = {
    for (final id in CollectorTypeArchetypeId.values) id: 0.0,
  };

  final seriesCount = snapshot.shelfSeries.length;
  final owned = stats.totalOwned;
  final wishlist = stats.totalWishlist;
  final totalTracked = owned + wishlist;
  final wishlistRatio =
      totalTracked == 0 ? 0.0 : wishlist / totalTracked;
  final secretOwnedRatio = stats.secretSlots == 0
      ? 0.0
      : stats.secretOwned / stats.secretSlots;
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
        progress.owned / total >= 0.85) {
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
      final cat = _catalogSeriesFor(catalog, series.catalogTemplateId!);
      if (cat != null && _isRecentRelease(cat, now)) recentCatalogSeries++;
    }
  }

  final brandSpread = stats.brandBreakdown.length;
  final ipDepthKeys = memory?.ipSeriesDepth.length ?? 0;

  // Completionist
  if (profile.seriesCompleteCount >= 2 && avgCompletion >= 0.7) {
    scores[CollectorTypeArchetypeId.completionist] =
        40 + profile.seriesCompleteCount * 12 + avgCompletion * 30;
  } else if (nearComplete >= 2) {
    scores[CollectorTypeArchetypeId.completionist] = 25 + nearComplete * 8;
  }

  // Hunter
  if (stats.secretOwned >= 2) {
    scores[CollectorTypeArchetypeId.hunter] =
        35 + stats.secretOwned * 10 + secretOwnedRatio * 25;
  } else if (profile.themeIncludes('secrets') && stats.secretOwned >= 1) {
    scores[CollectorTypeArchetypeId.hunter] = 20 + secretOwnedRatio * 20;
  }

  // Lucky One — high secret hit rate with modest shelf
  if (stats.secretOwned >= 1 &&
      secretOwnedRatio >= 0.5 &&
      seriesCount <= 4) {
    scores[CollectorTypeArchetypeId.luckyOne] =
        30 + secretOwnedRatio * 40;
  }

  // Loyalist — dominant brand/IP
  if (profile.dominantBrandId != null || profile.dominantIpId != null) {
    final dominantShare = _dominantShare(snapshot, profile);
    if (dominantShare >= 0.6) {
      scores[CollectorTypeArchetypeId.loyalist] =
          35 + dominantShare * 40;
    }
  }

  // Curator — spread across brands/IPs
  if (brandSpread >= 3 || ipDepthKeys >= 3) {
    scores[CollectorTypeArchetypeId.curator] =
        25 + brandSpread * 8 + ipDepthKeys * 5;
  }

  // Wanderer — many IPs, low completion
  if (brandSpread >= 2 && avgCompletion < 0.5 && seriesCount >= 2) {
    scores[CollectorTypeArchetypeId.wanderer] =
        20 + brandSpread * 6 + (1 - avgCompletion) * 20;
  }

  // Minimalist — small shelf, high completion
  if (seriesCount <= 3 && owned <= 12 && avgCompletion >= 0.75) {
    scores[CollectorTypeArchetypeId.minimalist] =
        35 + avgCompletion * 25;
  }

  // Archivist — notes, photos, long tenure
  if (notesCount >= 1 || photoSeries >= 2) {
    scores[CollectorTypeArchetypeId.archivist] =
        20 + notesCount * 10 + photoSeries * 8;
  }
  final firstAdded = memory?.firstSeriesAddedAt;
  if (firstAdded != null && now.difference(firstAdded).inDays >= 90) {
    scores[CollectorTypeArchetypeId.archivist] =
        (scores[CollectorTypeArchetypeId.archivist] ?? 0) + 15;
  }

  // Stylist — custom + photos
  if (stats.customSeriesRatio >= 0.3 || photoSeries >= 2) {
    scores[CollectorTypeArchetypeId.stylist] =
        25 + stats.customSeriesRatio * 40 + photoSeries * 6;
  }

  // Dreamer — wishlist leaning
  if (wishlistRatio >= 0.45 && wishlist >= 2) {
    scores[CollectorTypeArchetypeId.dreamer] =
        30 + wishlistRatio * 35;
  }

  // Daydream Collector — wishlist >> owned (stronger than dreamer when gap is wide)
  if (wishlist > owned && wishlist >= 3) {
    scores[CollectorTypeArchetypeId.daydreamCollector] =
        45 + (wishlist - owned) * 6 + wishlistRatio * 20;
  }

  // Trend Chaser — recent catalog releases on shelf
  if (recentCatalogSeries >= 2) {
    scores[CollectorTypeArchetypeId.trendChaser] =
        50 + recentCatalogSeries * 14;
  } else if (recentCatalogSeries == 1 && seriesCount <= 4) {
    scores[CollectorTypeArchetypeId.trendChaser] = 28;
  }

  return scores;
}

CollectorTypeArchetypeId _pickWinner(Map<CollectorTypeArchetypeId, double> scores) {
  var bestScore = -1.0;
  CollectorTypeArchetypeId? bestId;
  for (final e in scores.entries) {
    if (e.value > bestScore) {
      bestScore = e.value;
      bestId = e.key;
    }
  }
  if (bestId == null || bestScore <= 0) {
    return CollectorTypeArchetypeId.wanderer;
  }

  final tied = scores.entries
      .where((e) => (e.value - bestScore).abs() < 0.01)
      .map((e) => e.key)
      .toSet();
  if (tied.length == 1) return bestId;

  for (final id in CollectorTypeArchetypes.tieBreakPriority) {
    if (tied.contains(id)) return id;
  }
  return bestId;
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

seed.CatalogSeries? _catalogSeriesFor(CatalogSeedBundle catalog, String id) {
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
    return now.difference(released).inDays <= 180;
  } catch (_) {
    return false;
  }
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
