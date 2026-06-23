import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';

/// Result of [pickHomeFeedSeries] — catalog series ids before [SeriesRelease] build.
@immutable
class HomeFeedSeriesPick {
  const HomeFeedSeriesPick({
    required this.latest,
    required this.trending,
  });

  final List<CatalogSeries> latest;
  final List<CatalogSeries> trending;
}

/// Recent drops window (inclusive lower bound). Every dated series in this
/// window appears in Latest Drops — no item cap.
const Duration homeLatestDropsWindow = Duration(days: 60);

/// Trending primary pool: releases older than [homeLatestDropsWindow], up to ~12 months.
const Duration homeTrendingWindowEnd = Duration(days: 365);

const int homeTrendingTargetCount = 8;

/// Minimum before [backfillHomeFeedSection] expands by nearest [releaseDate].
const int homeTrendingMinimumCount = 5;

/// Curated collector-popular IPs — only used when series exist in the loaded bundle.
const List<String> homeCollectorPopularIpIds = [
  'the_monsters',
  'skullpanda',
  'hirono',
  'crybaby',
  'dimoo',
  'molly',
  'baby_molly',
  'space_molly',
];

/// Picks catalog series for Latest Drops and Trending using [releaseDate] only.
HomeFeedSeriesPick pickHomeFeedSeries(
  CatalogSeedBundle bundle, {
  DateTime? clock,
  Random? random,
}) {
  final now = _day(clock ?? DateTime.now());
  final rng = random ?? Random();
  final dated = bundle.series
      .map((s) => (series: s, date: _parseReleaseDate(s.releaseDate)))
      .where((e) => e.date != null)
      .toList(growable: false);

  final latestCutoff = now.subtract(homeLatestDropsWindow);
  final trendingStart = now.subtract(homeTrendingWindowEnd);
  final trendingEnd = now.subtract(homeLatestDropsWindow);

  final latest = dated
      .where((e) => !e.date!.isBefore(latestCutoff))
      .map((e) => e.series)
      .toList(growable: false)
    ..sort((a, b) => _parseReleaseDate(b.releaseDate)!.compareTo(_parseReleaseDate(a.releaseDate)!));

  final latestIds = latest.map((s) => s.id).toSet();

  final trendingPool = dated
      .where((e) {
        final d = e.date!;
        return !d.isBefore(trendingStart) &&
            d.isBefore(trendingEnd) &&
            !latestIds.contains(e.series.id);
      })
      .map((e) => e.series)
      .toList(growable: false);

  var trending = _shuffleCopy(trendingPool, rng).take(homeTrendingTargetCount).toList(growable: false);

  if (trending.length < homeTrendingMinimumCount) {
    trending = _appendCollectorPopularFallback(
      bundle: bundle,
      dated: dated,
      current: trending,
      excludeIds: latestIds,
      target: homeTrendingTargetCount,
      rng: rng,
    );
  }

  if (trending.length < homeTrendingMinimumCount) {
    trending = backfillHomeFeedSection(
      dated,
      current: trending,
      target: homeTrendingTargetCount,
      minimum: homeTrendingMinimumCount,
      anchor: trendingEnd,
      excludeIds: latestIds,
      releaseOnOrAfter: trendingStart,
      releaseBefore: trendingEnd,
    );
  }
  if (trending.length < homeTrendingMinimumCount) {
    trending = backfillHomeFeedSection(
      dated,
      current: trending,
      target: homeTrendingTargetCount,
      minimum: homeTrendingMinimumCount,
      anchor: trendingEnd,
      excludeIds: latestIds,
    );
  }

  return HomeFeedSeriesPick(latest: latest, trending: trending);
}

List<CatalogSeries> _appendCollectorPopularFallback({
  required CatalogSeedBundle bundle,
  required List<({CatalogSeries series, DateTime? date})> dated,
  required List<CatalogSeries> current,
  required Set<String> excludeIds,
  required int target,
  required Random rng,
}) {
  final seen = {for (final s in current) s.id, ...excludeIds};
  final out = List<CatalogSeries>.from(current);

  for (final ipId in homeCollectorPopularIpIds) {
    if (out.length >= target) break;
    final candidates = dated
        .where((e) => e.series.ipId == ipId && !seen.contains(e.series.id))
        .toList(growable: false)
      ..sort((a, b) => b.date!.compareTo(a.date!));
    for (final c in candidates) {
      if (out.length >= target) break;
      out.add(c.series);
      seen.add(c.series.id);
    }
  }

  if (out.length <= current.length) return current;
  final tail = _shuffleCopy(out.skip(current.length).toList(), rng);
  return [...current, ...tail].take(target).toList(growable: false);
}

/// Fills [current] toward [target] with nearest-dated series not already included.
List<CatalogSeries> backfillHomeFeedSection(
  List<({CatalogSeries series, DateTime? date})> dated, {
  required List<CatalogSeries> current,
  required int target,
  required int minimum,
  required DateTime anchor,
  Set<String> excludeIds = const {},
  DateTime? releaseOnOrAfter,
  DateTime? releaseBefore,
}) {
  if (current.length >= minimum) return current.take(target).toList(growable: false);

  final seen = {for (final s in current) s.id, ...excludeIds};
  final ranked = dated
      .where((e) {
        if (e.date == null || seen.contains(e.series.id)) return false;
        final d = e.date!;
        if (releaseOnOrAfter != null && d.isBefore(releaseOnOrAfter)) return false;
        if (releaseBefore != null && !d.isBefore(releaseBefore)) return false;
        return true;
      })
      .toList(growable: false)
    ..sort((a, b) {
      final da = a.date!.difference(anchor).inDays.abs();
      final db = b.date!.difference(anchor).inDays.abs();
      final byDist = da.compareTo(db);
      if (byDist != 0) return byDist;
      return b.date!.compareTo(a.date!);
    });

  final out = List<CatalogSeries>.from(current);
  for (final e in ranked) {
    if (out.length >= target) break;
    out.add(e.series);
    seen.add(e.series.id);
  }
  return out;
}

List<CatalogSeries> _shuffleCopy(List<CatalogSeries> items, Random rng) {
  final copy = List<CatalogSeries>.from(items);
  for (var i = copy.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = copy[i];
    copy[i] = copy[j];
    copy[j] = tmp;
  }
  return copy;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _parseReleaseDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    return _day(DateTime.parse(iso));
  } catch (_) {
    return null;
  }
}
