import 'dart:math';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/recommendations/data/catalog_exploration_fingerprint.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';

const int _recencyWindowDays = 90;

class _ScoredCandidate {
  _ScoredCandidate({
    required this.seriesId,
    required this.score,
    required this.reasonType,
    this.reasonMeta,
  });

  final String seriesId;
  int score;
  String reasonType;
  String? reasonMeta;
}

/// Local rule engine — mirrors the Cloud Function scoring pipeline.
List<RecommendationItem> computeLocalRecommendations({
  required PreferenceSignals signals,
  required CatalogSeedBundle bundle,
  DateTime? clock,
  int limit = RecommendationGatewayConfig.forYouResultLimit,
}) {
  final now = clock ?? DateTime.now();
  final ipNameById = {
    for (final ip in bundle.ips) ip.id: ip.displayName,
  };
  final orderIndex = <String, int>{
    for (var i = 0; i < bundle.series.length; i++) bundle.series[i].id: i,
  };

  final scored = <String, _ScoredCandidate>{};

  void upsert(
    catalog.CatalogSeries series, {
    required int score,
    required String reasonType,
    String? reasonMeta,
  }) {
    final existing = scored[series.id];
    if (existing == null) {
      scored[series.id] = _ScoredCandidate(
        seriesId: series.id,
        score: score,
        reasonType: reasonType,
        reasonMeta: reasonMeta,
      );
      return;
    }
    if (score > existing.score) {
      existing
        ..score = score
        ..reasonType = reasonType
        ..reasonMeta = reasonMeta;
    }
  }

  bool isTracked(catalog.CatalogSeries series) =>
      signals.trackedCatalogSeriesIds.contains(series.id);

  for (final series in bundle.series) {
    if (isTracked(series)) continue;

    if (signals.trackedIpIds.contains(series.ipId)) {
      upsert(
        series,
        score: 30,
        reasonType: RecommendationReasonType.trackedIp,
        reasonMeta: ipNameById[series.ipId] ?? series.ipId,
      );
    }
  }

  for (final entry in scored.values) {
    final series = bundle.series.firstWhere(
      (candidate) => candidate.id == entry.seriesId,
      orElse: () => catalog.CatalogSeries(
        id: entry.seriesId,
        brandId: '',
        ipId: '',
        displayName: entry.seriesId,
        releaseDate: null,
        isBlindBox: true,
        imageKey: entry.seriesId,
      ),
    );
    if (_isRecentRelease(series, now)) {
      entry
        ..score += 10
        ..reasonType = RecommendationReasonType.recentRelease
        ..reasonMeta = null;
    }
  }

  final ranked = scored.values.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final seriesA = bundle.series.firstWhere(
        (candidate) => candidate.id == a.seriesId,
        orElse: () => catalog.CatalogSeries(
          id: a.seriesId,
          brandId: '',
          ipId: '',
          displayName: a.seriesId,
          releaseDate: null,
          isBlindBox: true,
          imageKey: a.seriesId,
        ),
      );
      final seriesB = bundle.series.firstWhere(
        (candidate) => candidate.id == b.seriesId,
        orElse: () => catalog.CatalogSeries(
          id: b.seriesId,
          brandId: '',
          ipId: '',
          displayName: b.seriesId,
          releaseDate: null,
          isBlindBox: true,
          imageKey: b.seriesId,
        ),
      );
      return _compareNewestFirst(seriesA, seriesB, orderIndex);
    });

  final seriesById = {for (final series in bundle.series) series.id: series};
  final diversified = _applyIpDiversity(
    ranked: ranked,
    ipIdForSeries: (seriesId) => seriesById[seriesId]?.ipId ?? seriesId,
  );

  final results = List<RecommendationItem>.from(
    _composeCuratedResults(
      ranked: diversified,
      limit: limit,
      explorationSeed: _explorationSeed(
        signals.profileHash,
        catalogExplorationFingerprint(bundle),
      ),
    ),
  );

  final minimum = RecommendationGatewayConfig.forYouMinimumResultCount;
  if (results.length >= minimum) return results;

  final gapFillSorted = bundle.series.toList()
    ..sort((a, b) => _compareNewestFirst(a, b, orderIndex));
  final gapFillIpCounts = _ipCountsForResults(results, seriesById);
  final catalogFingerprint = catalogExplorationFingerprint(bundle);

  _appendGapFillResults(
    results: results,
    minimum: minimum,
    sortedCatalog: gapFillSorted,
    isTracked: isTracked,
    scoredIds: scored.keys.toSet(),
    gapFillIpCounts: gapFillIpCounts,
    gapFillSeed: _gapFillSeed(signals.profileHash, catalogFingerprint),
  );

  return results;
}

void _appendGapFillResults({
  required List<RecommendationItem> results,
  required int minimum,
  required List<catalog.CatalogSeries> sortedCatalog,
  required bool Function(catalog.CatalogSeries series) isTracked,
  required Set<String> scoredIds,
  required Map<String, int> gapFillIpCounts,
  required int gapFillSeed,
}) {
  final eligible = <catalog.CatalogSeries>[];
  for (final series in sortedCatalog) {
    if (isTracked(series)) continue;
    if (scoredIds.contains(series.id)) continue;
    eligible.add(series);
  }

  final poolSize = RecommendationGatewayConfig.forYouGapFillRecentPoolSize;
  final recentPool = eligible.take(poolSize).toList();
  final remainder = eligible.skip(poolSize).toList();

  void addFromCandidates(
    List<catalog.CatalogSeries> candidates, {
    required bool shuffle,
  }) {
    final queue = List<catalog.CatalogSeries>.from(candidates);
    if (shuffle) {
      queue.shuffle(Random(gapFillSeed));
    }
    for (final series in queue) {
      if (results.length >= minimum) return;
      if (!_canAddSeriesForIp(
        series.ipId,
        gapFillIpCounts,
        RecommendationGatewayConfig.forYouMaxSeriesPerIp,
      )) {
        continue;
      }
      gapFillIpCounts[series.ipId] = (gapFillIpCounts[series.ipId] ?? 0) + 1;
      results.add(
        RecommendationItem(
          seriesId: series.id,
          reasonType: RecommendationReasonType.newInCatalog,
        ),
      );
    }
  }

  addFromCandidates(recentPool, shuffle: true);
  if (results.length < minimum) {
    addFromCandidates(remainder, shuffle: false);
  }
}

int _gapFillSeed(String profileHash, String catalogFingerprint) {
  return Object.hash('gap_fill', profileHash, catalogFingerprint);
}

List<_ScoredCandidate> _applyIpDiversity({
  required List<_ScoredCandidate> ranked,
  required String Function(String seriesId) ipIdForSeries,
  int maxPerIp = RecommendationGatewayConfig.forYouMaxSeriesPerIp,
}) {
  final ipCounts = <String, int>{};
  final diversified = <_ScoredCandidate>[];
  for (final candidate in ranked) {
    final ipId = ipIdForSeries(candidate.seriesId);
    if (!_canAddSeriesForIp(ipId, ipCounts, maxPerIp)) continue;
    ipCounts[ipId] = (ipCounts[ipId] ?? 0) + 1;
    diversified.add(candidate);
  }
  return diversified;
}

bool _canAddSeriesForIp(
  String ipId,
  Map<String, int> ipCounts,
  int maxPerIp,
) {
  return (ipCounts[ipId] ?? 0) < maxPerIp;
}

Map<String, int> _ipCountsForResults(
  List<RecommendationItem> results,
  Map<String, catalog.CatalogSeries> seriesById,
) {
  final ipCounts = <String, int>{};
  for (final item in results) {
    final ipId = seriesById[item.seriesId]?.ipId ?? item.seriesId;
    ipCounts[ipId] = (ipCounts[ipId] ?? 0) + 1;
  }
  return ipCounts;
}

List<RecommendationItem> _composeCuratedResults({
  required List<_ScoredCandidate> ranked,
  required int limit,
  required int explorationSeed,
}) {
  if (ranked.isEmpty) return <RecommendationItem>[];

  final stableSlots = RecommendationGatewayConfig.forYouStableSlotCount(limit);
  final exploreSlots = RecommendationGatewayConfig.forYouExplorationSlotCount(limit);
  final stableCount = min(stableSlots, ranked.length);
  final stable = ranked.take(stableCount);
  final explorePool = ranked.skip(stableCount).toList();
  final explored = _pickExploration(
    explorePool,
    min(exploreSlots, limit - stableCount),
    explorationSeed,
  );

  return [
    for (final candidate in [...stable, ...explored])
      RecommendationItem(
        seriesId: candidate.seriesId,
        reasonType: candidate.reasonType,
        reasonMeta: candidate.reasonMeta,
      ),
  ];
}

int _explorationSeed(String profileHash, String catalogFingerprint) {
  return Object.hash(profileHash, catalogFingerprint);
}

List<_ScoredCandidate> _pickExploration(
  List<_ScoredCandidate> pool,
  int count,
  int seed,
) {
  if (pool.isEmpty || count <= 0) return const [];
  final shuffled = List<_ScoredCandidate>.from(pool)..shuffle(Random(seed));
  return shuffled.take(count).toList();
}

bool _isRecentRelease(catalog.CatalogSeries series, DateTime clock) {
  final parsed = _parseReleaseDate(series.releaseDate);
  if (parsed == null) return false;
  return clock.difference(parsed).inDays <= _recencyWindowDays;
}

DateTime? _parseReleaseDate(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}

int _compareNewestFirst(
  catalog.CatalogSeries a,
  catalog.CatalogSeries b,
  Map<String, int> orderIndex,
) {
  final da = a.releaseDate;
  final db = b.releaseDate;
  if (da != null && db != null) {
    final byDate = db.compareTo(da);
    if (byDate != 0) return byDate;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  final ia = orderIndex[a.id] ?? 0;
  final ib = orderIndex[b.id] ?? 0;
  return ib.compareTo(ia);
}