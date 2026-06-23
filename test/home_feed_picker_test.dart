import 'dart:math';

import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/home/data/home_feed_picker.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeedBundle _bundle(List<CatalogSeries> series) => CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'popmart', displayName: 'POP MART')],
      ips: const [
        CatalogIp(id: 'skullpanda', brandId: 'popmart', displayName: 'Skullpanda'),
        CatalogIp(id: 'the_monsters', brandId: 'popmart', displayName: 'THE MONSTERS'),
      ],
      series: series,
      figures: const [],
    );

CatalogSeries _series(String id, String date, {String ipId = 'skullpanda'}) =>
    CatalogSeries(
      id: id,
      brandId: 'popmart',
      ipId: ipId,
      displayName: id,
      releaseDate: date,
      isBlindBox: true,
      imageKey: id,
    );

void main() {
  final clock = DateTime(2026, 5, 21);

  test('latest includes every release within 60 days, newest first', () {
    final bundle = _bundle([
      _series('a', '2026-05-10'),
      _series('b', '2026-04-20'),
      _series('c', '2026-03-25'),
      _series('d', '2026-03-22'),
      _series('outside', '2026-03-21'),
      _series('ancient', '2025-01-01'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(1));
    expect(pick.latest.map((s) => s.id), ['a', 'b', 'c', 'd']);
    expect(pick.latest.any((s) => s.id == 'outside'), isFalse);
    expect(pick.latest.any((s) => s.id == 'ancient'), isFalse);
  });

  test('latest does not truncate when more than 8 series are eligible', () {
    final bundle = _bundle([
      for (var i = 0; i < 12; i++)
        _series('drop_$i', '2026-04-${(22 + i).toString().padLeft(2, '0')}'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(1));
    expect(pick.latest, hasLength(12));
    expect(
      pick.latest.map((s) => s.id),
      [for (var i = 11; i >= 0; i--) 'drop_$i'],
    );
  });

  test('trending uses 60-day to 12-month window and excludes latest', () {
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-15'),
      _series('l3', '2026-04-01'),
      _series('l4', '2026-03-20'),
      _series('trend_a', '2025-10-01'),
      _series('trend_b', '2025-08-15'),
      _series('trend_c', '2025-07-01'),
      _series('trend_d', '2025-06-10'),
      _series('trend_e', '2025-06-01'),
      _series('too_old', '2024-01-01'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(2));
    for (final id in ['l1', 'l2', 'l3']) {
      expect(pick.latest.map((s) => s.id), contains(id));
    }
    expect(pick.latest.map((s) => s.id), isNot(contains('l4')));
    for (final id in ['l1', 'l2', 'l3']) {
      expect(pick.trending.map((s) => s.id), isNot(contains(id)));
    }
    expect(pick.trending.map((s) => s.id), contains('l4'));
    expect(
      pick.trending.map((s) => s.id),
      containsAll(['trend_a', 'trend_b', 'trend_c', 'trend_d', 'trend_e']),
    );
    expect(pick.trending.any((s) => s.id == 'too_old'), isFalse);
  });

  test('latest and trending never share a series id', () {
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-15'),
      _series('l3', '2026-04-01'),
      _series('l4', '2026-03-20'),
      _series('trend_a', '2025-10-01'),
      _series('trend_b', '2025-08-15'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(4));
    final latestIds = pick.latest.map((s) => s.id).toSet();
    final trendingIds = pick.trending.map((s) => s.id).toSet();
    expect(latestIds.intersection(trendingIds), isEmpty);
  });

  test('collector-popular fallback fills thin trending from known ips', () {
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-20'),
      _series('l3', '2026-04-05'),
      _series('l4', '2026-03-15'),
      _series('sp_old', '2025-06-01', ipId: 'skullpanda'),
      _series('labubu', '2025-05-01', ipId: 'the_monsters'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(3));
    expect(pick.trending.map((s) => s.id), contains('labubu'));
  });
}
