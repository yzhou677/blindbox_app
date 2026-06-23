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

/// Trending window: releases older than [homeLatestDropsWindow], up to 120 days.
const Duration homeTrendingWindowEnd = Duration(days: 120);

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

  final trending = _shuffleCopy(trendingPool, rng);

  return HomeFeedSeriesPick(latest: latest, trending: trending);
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
