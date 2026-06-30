import 'dart:math';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
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

  tearDown(resetTrendingSessionOrderForTest);

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

  test('trending uses 60-day to 120-day window and excludes latest', () {
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-15'),
      _series('l3', '2026-04-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-03-01'),
      _series('t3', '2026-02-10'),
      _series('t4', '2026-01-25'),
      _series('t5', '2026-01-22'),
      _series('too_recent', '2026-03-22'),
      _series('too_old', '2026-01-20', ipId: 'nommi'),
      _series('ancient', '2025-10-01', ipId: 'nommi'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(2));
    for (final id in ['l1', 'l2', 'l3', 'too_recent']) {
      expect(pick.latest.map((s) => s.id), contains(id));
    }
    for (final id in ['l1', 'l2', 'l3', 'too_recent']) {
      expect(pick.trending.map((s) => s.id), isNot(contains(id)));
    }
    expect(
      pick.trending.map((s) => s.id),
      containsAll(['t1', 't2', 't3', 't4', 't5']),
    );
    expect(pick.trending.any((s) => s.id == 'too_old'), isFalse);
    expect(pick.trending.any((s) => s.id == 'ancient'), isFalse);
  });

  test('trending does not truncate when more than 8 series are eligible', () {
    final bundle = _bundle([
      _series('latest_only', '2026-05-01'),
      for (var i = 0; i < 12; i++)
        _series('trend_$i', '2026-02-${(10 + i).toString().padLeft(2, '0')}'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(5));
    expect(pick.trending, hasLength(12));
    for (var i = 0; i < 12; i++) {
      expect(pick.trending.map((s) => s.id), contains('trend_$i'));
    }
  });

  test('latest and trending never share a series id', () {
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-15'),
      _series('l3', '2026-04-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-02-10'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(4));
    final latestIds = pick.latest.map((s) => s.id).toSet();
    final trendingIds = pick.trending.map((s) => s.id).toSet();
    expect(latestIds.intersection(trendingIds), isEmpty);
  });

  test('trending stays within window when pool is thin', () {
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-20'),
      _series('l3', '2026-04-05'),
      _series('t1', '2026-03-15'),
      _series('sp_old', '2025-06-01', ipId: 'skullpanda'),
      _series('labubu', '2025-05-01', ipId: 'the_monsters'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(3));
    expect(pick.trending.map((s) => s.id), ['t1']);
    expect(pick.trending.any((s) => s.id == 'labubu'), isFalse);
    expect(pick.trending.any((s) => s.id == 'sp_old'), isFalse);
  });

  test('trending is empty when nothing falls in the 60-120 day window', () {
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-15'),
      _series('ancient', '2025-01-01'),
    ]);
    final pick = pickHomeFeedSeries(bundle, clock: clock, random: Random(1));
    expect(pick.trending, isEmpty);
  });

  test('trending session order stays stable across repeated picks', () {
    seedTrendingSessionRandomForTest(42);
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('l2', '2026-04-15'),
      _series('l3', '2026-04-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-02-10'),
      _series('t3', '2026-01-25'),
    ]);
    final first = pickHomeFeedSeries(bundle, clock: clock);
    final second = pickHomeFeedSeries(bundle, clock: clock);
    expect(
      second.trending.map((s) => s.id),
      first.trending.map((s) => s.id),
    );
    expect(first.latest.map((s) => s.id), second.latest.map((s) => s.id));
  });

  test('trending session order can change after a new session', () {
    seedTrendingSessionRandomForTest(1);
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-02-10'),
      _series('t3', '2026-01-25'),
    ]);
    final firstOrder =
        pickHomeFeedSeries(bundle, clock: clock).trending.map((s) => s.id).toList();

    resetTrendingSessionOrderForTest();
    seedTrendingSessionRandomForTest(99);
    final secondOrder =
        pickHomeFeedSeries(bundle, clock: clock).trending.map((s) => s.id).toList();

    expect(secondOrder, isNot(firstOrder));
  });

  test('trending keeps order when pool membership is unchanged', () {
    seedTrendingSessionRandomForTest(7);
    final bundle = _bundle([
      _series('l1', '2026-05-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-02-10'),
      _series('t3', '2026-01-25'),
    ]);
    final firstOrder =
        pickHomeFeedSeries(bundle, clock: clock).trending.map((s) => s.id).toList();
    final refreshedOrder =
        pickHomeFeedSeries(bundle, clock: clock).trending.map((s) => s.id).toList();

    expect(refreshedOrder, firstOrder);
  });

  test('trending reshuffles entire pool when membership changes', () {
    seedTrendingSessionRandomForTest(42);
    final base = [
      _series('l1', '2026-05-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-02-10'),
      _series('t3', '2026-01-25'),
    ];
    final firstOrder = pickHomeFeedSeries(_bundle(base), clock: clock)
        .trending
        .map((s) => s.id)
        .toList();

    final withNew = [
      ...base,
      _series('t4', '2026-02-01'),
    ];
    final secondOrder = pickHomeFeedSeries(_bundle(withNew), clock: clock)
        .trending
        .map((s) => s.id)
        .toList();

    expect(secondOrder, hasLength(4));
    expect(secondOrder.toSet(), containsAll(['t1', 't2', 't3', 't4']));
    expect(
      secondOrder.where(firstOrder.contains).toList(),
      isNot(firstOrder),
    );
  });

  test('trending drops removed series when pool membership changes', () {
    seedTrendingSessionRandomForTest(3);
    final full = [
      _series('l1', '2026-05-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-02-10'),
      _series('t3', '2026-01-25'),
    ];
    pickHomeFeedSeries(_bundle(full), clock: clock);

    final reduced = [
      _series('l1', '2026-05-01'),
      _series('t1', '2026-03-15'),
      _series('t2', '2026-02-10'),
    ];
    final trending =
        pickHomeFeedSeries(_bundle(reduced), clock: clock).trending;

    expect(trending, hasLength(2));
    expect(trending.map((s) => s.id), isNot(contains('t3')));
  });
}
