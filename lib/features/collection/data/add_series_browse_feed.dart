import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_latest_series.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/data/home_feed_picker.dart';

/// Target row count for the Add Series browse list (alternating latest/trending).
const int addSeriesBrowseFeedTargetCount = 10;

/// Lightweight mixed browse for Add Series — ~50% Latest Drops pool, ~50% Trending.
///
/// Reuses [pickHomeFeedSeries] date windows (same catalog semantics as Discover).
/// Falls back to newest-by-date when dated pools are empty (e.g. test fixtures).
List<catalog.CatalogSeries> pickAddSeriesBrowseFeed(
  CatalogSeedBundle bundle, {
  int targetCount = addSeriesBrowseFeedTargetCount,
  DateTime? clock,
}) {
  final pick = pickHomeFeedSeries(bundle, clock: clock);
  final interleaved = interleaveCatalogSeriesPools(
    latest: pick.latest,
    trending: pick.trending,
    targetCount: targetCount,
  );
  if (interleaved.isNotEmpty) return interleaved;

  return pickLatestSeriesRecommendations(
    bundle,
    const CollectionSnapshot(
      shelfSeries: [],
      figureStates: {},
    ),
    limit: targetCount,
  );
}

/// Alternates [latest] and [trending], skipping duplicate series ids.
List<catalog.CatalogSeries> interleaveCatalogSeriesPools({
  required List<catalog.CatalogSeries> latest,
  required List<catalog.CatalogSeries> trending,
  required int targetCount,
}) {
  if (targetCount <= 0) return const [];

  final seen = <String>{};
  final results = <catalog.CatalogSeries>[];
  var latestIndex = 0;
  var trendingIndex = 0;
  var preferLatest = true;

  while (results.length < targetCount) {
    catalog.CatalogSeries? next;
    if (preferLatest) {
      next = _takeNext(latest, latestIndex, seen);
      if (next != null) {
        latestIndex = latest.indexOf(next) + 1;
      } else {
        next = _takeNext(trending, trendingIndex, seen);
        if (next != null) trendingIndex = trending.indexOf(next) + 1;
      }
    } else {
      next = _takeNext(trending, trendingIndex, seen);
      if (next != null) {
        trendingIndex = trending.indexOf(next) + 1;
      } else {
        next = _takeNext(latest, latestIndex, seen);
        if (next != null) latestIndex = latest.indexOf(next) + 1;
      }
    }

    if (next == null) break;
    seen.add(next.id);
    results.add(next);
    preferLatest = !preferLatest;
  }

  return results;
}

catalog.CatalogSeries? _takeNext(
  List<catalog.CatalogSeries> pool,
  int startIndex,
  Set<String> seen,
) {
  for (var i = startIndex; i < pool.length; i++) {
    final candidate = pool[i];
    if (seen.contains(candidate.id)) continue;
    return candidate;
  }
  return null;
}
