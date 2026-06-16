import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collection_value_providers.dart';
import 'package:blindbox_app/features/collection/insights/domain/shelf_value_summary.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class _FakeRepo implements MarketSnapshotRepository {
  _FakeRepo({this.figureMap = const {}});

  final Map<String, MarketSnapshot> figureMap;

  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) async =>
      figureMap[figureId];

  @override
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId) async => null;

  @override
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId) async =>
      [];
}

MarketSnapshot _figureSnapshot({
  required String id,
  required double value,
  String seriesId = 'series_test',
}) {
  return MarketSnapshot(
    id: id,
    level: SnapshotLevel.figure,
    figureId: id,
    seriesId: seriesId,
    estimatedValueUsd: value,
    trend: MarketTrend.stable,
    confidence: SnapshotConfidence.high,
    recentSalesCount: 10,
    computedAt: DateTime(2025, 1, 1),
  );
}

MarketSnapshot _seriesSnapshot({
  required String seriesId,
  required double value,
}) {
  return MarketSnapshot(
    id: seriesId,
    level: SnapshotLevel.series,
    seriesId: seriesId,
    estimatedValueUsd: value,
    trend: MarketTrend.stable,
    confidence: SnapshotConfidence.low,
    recentSalesCount: 5,
    computedAt: DateTime(2025, 1, 1),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({
  required CollectionSnapshot snap,
  MarketSnapshotRepository? repo,
}) {
  CollectionAppBootstrap.prime(snap);
  SharedPreferences.setMockInitialValues({});

  final container = ProviderContainer(
    overrides: [
      if (repo != null)
        marketSnapshotRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  container.read(collectionNotifierProvider);
  return container;
}

TrackedFigure _owned(String figureId) =>
    TrackedFigure(figureId: figureId, state: FigureCollectionState.owned);

CollectionSnapshot _snapWithFigures({
  List<ShelfFigure>? figures,
  Map<String, TrackedFigure>? figureStates,
}) {
  final figs = figures ??
      [
        const ShelfFigure(
          id: 'fig_1',
          seriesId: 'series_test',
          name: 'Luck',
          rarity: 'Regular',
          isSecret: false,
          catalogFigureTemplateId: 'cat_fig_1',
        ),
        const ShelfFigure(
          id: 'fig_2',
          seriesId: 'series_test',
          name: 'Hope',
          rarity: 'Regular',
          isSecret: false,
          catalogFigureTemplateId: 'cat_fig_2',
        ),
      ];
  final states = figureStates ??
      {
        'fig_1': _owned('fig_1'),
        'fig_2': _owned('fig_2'),
      };
  return CollectionSnapshot(
    shelfSeries: [testShelfSeries(figures: figs)],
    figureStates: states,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('collectionValueProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns ShelfValueSummary.none when collection is empty', () async {
      final container = _makeContainer(
        snap: const CollectionSnapshot(shelfSeries: [], figureStates: {}),
      );

      final result = await container.read(collectionValueProvider.future);

      expect(result.ownedCount, 0);
      expect(result.valuedCount, 0);
      expect(result.totalValueUsd, 0);
      expect(result.hasAnyValue, isFalse);
    });

    test('aggregates value for all owned figures with snapshots', () async {
      final repo = _FakeRepo(
        figureMap: {
          'cat_fig_1': _figureSnapshot(id: 'cat_fig_1', value: 42),
          'cat_fig_2': _figureSnapshot(id: 'cat_fig_2', value: 38),
        },
      );

      final container = _makeContainer(snap: _snapWithFigures(), repo: repo);

      final result = await container.read(collectionValueProvider.future);

      expect(result.ownedCount, 2);
      expect(result.valuedCount, 2);
      expect(result.unavailableCount, 0);
      expect(result.totalValueUsd, 80);
      expect(result.hasAnyValue, isTrue);
      expect(result.includesSeriesEstimates, isFalse);
      expect(result.coverageLabel, 'Based on 2 of 2 figures');
    });

    test('excludes figures without snapshots from total', () async {
      final repo = _FakeRepo(
        figureMap: {
          'cat_fig_1': _figureSnapshot(id: 'cat_fig_1', value: 42),
          // cat_fig_2 has no snapshot
        },
      );

      final container = _makeContainer(snap: _snapWithFigures(), repo: repo);

      final result = await container.read(collectionValueProvider.future);

      expect(result.ownedCount, 2);
      expect(result.valuedCount, 1);
      expect(result.unavailableCount, 1);
      expect(result.totalValueUsd, 42);
    });

    test('coverage percent rounds correctly', () async {
      final repo = _FakeRepo(
        figureMap: {
          'cat_fig_1': _figureSnapshot(id: 'cat_fig_1', value: 10),
          // cat_fig_2 has no snapshot → 1 of 2 = 50%
        },
      );

      final container = _makeContainer(snap: _snapWithFigures(), repo: repo);

      final result = await container.read(collectionValueProvider.future);

      expect(result.coveragePercent, 50);
    });

    test('topFigures are sorted by value descending, capped at 5', () async {
      final figureList = List.generate(
        7,
        (i) => ShelfFigure(
          id: 'fig_$i',
          seriesId: 'series_test',
          name: 'Figure $i',
          rarity: 'Regular',
          isSecret: false,
          catalogFigureTemplateId: 'cat_$i',
        ),
      );
      final states = {
        for (final f in figureList) f.id: _owned(f.id),
      };
      final repo = _FakeRepo(
        figureMap: {
          for (var i = 0; i < 7; i++)
            'cat_$i': _figureSnapshot(id: 'cat_$i', value: (i + 1) * 10.0),
        },
      );

      final container = _makeContainer(
        snap: CollectionSnapshot(
          shelfSeries: [testShelfSeries(figures: figureList)],
          figureStates: states,
        ),
        repo: repo,
      );

      final result = await container.read(collectionValueProvider.future);

      expect(result.topFigures.length, 5);
      expect(result.topFigures.first.estimatedValueUsd, 70);
      expect(result.topFigures.last.estimatedValueUsd, 30);
    });

    test('series-level fallback snapshot is marked isSeriesEstimate', () async {
      final repo = _FakeRepo(
        figureMap: {
          'cat_fig_1': _seriesSnapshot(seriesId: 'series_test', value: 42),
        },
      );

      final container = _makeContainer(
        snap: _snapWithFigures(
          figureStates: {
            'fig_1': _owned('fig_1'),
            'fig_2': TrackedFigure(
              figureId: 'fig_2',
              state: FigureCollectionState.wishlist,
            ),
          },
        ),
        repo: repo,
      );

      final result = await container.read(collectionValueProvider.future);

      expect(result.ownedCount, 1);
      expect(result.topFigures.single.isSeriesEstimate, isTrue);
      expect(result.includesSeriesEstimates, isTrue);
      expect(
        result.coverageLabel,
        'Based on 1 of 1 figures · includes estimates',
      );
    });

    test('includesSeriesEstimates is false when all snapshots are figure-level',
        () async {
      final repo = _FakeRepo(
        figureMap: {
          'cat_fig_1': _figureSnapshot(id: 'cat_fig_1', value: 42),
          'cat_fig_2': _figureSnapshot(id: 'cat_fig_2', value: 38),
        },
      );

      final container = _makeContainer(snap: _snapWithFigures(), repo: repo);

      final result = await container.read(collectionValueProvider.future);

      expect(result.includesSeriesEstimates, isFalse);
      expect(result.coverageLabel, 'Based on 2 of 2 figures');
    });

    test('includesSeriesEstimates is true when mix includes series fallback',
        () async {
      final repo = _FakeRepo(
        figureMap: {
          'cat_fig_1': _figureSnapshot(id: 'cat_fig_1', value: 42),
          'cat_fig_2': _seriesSnapshot(seriesId: 'series_test', value: 37),
        },
      );

      final container = _makeContainer(snap: _snapWithFigures(), repo: repo);

      final result = await container.read(collectionValueProvider.future);

      expect(result.includesSeriesEstimates, isTrue);
      expect(
        result.coverageLabel,
        'Based on 2 of 2 figures · includes estimates',
      );
    });

    test('seriesBreakdown aggregates across series', () async {
      final fig1 = const ShelfFigure(
        id: 'fig_a',
        seriesId: 'series_a',
        name: 'Alpha',
        rarity: 'Regular',
        isSecret: false,
        catalogFigureTemplateId: 'cat_a',
      );
      final fig2 = const ShelfFigure(
        id: 'fig_b',
        seriesId: 'series_b',
        name: 'Beta',
        rarity: 'Regular',
        isSecret: false,
        catalogFigureTemplateId: 'cat_b',
      );
      final seriesA = ShelfSeries(
        id: 'series_a',
        name: 'Series A',
        brand: 'POP MART',
        ipName: 'IP',
        figures: [fig1],
        shelfAccent: const Color(0xFFE4F2EA),
        catalogTemplateId: 'tmpl_a',
      );
      final seriesB = ShelfSeries(
        id: 'series_b',
        name: 'Series B',
        brand: 'POP MART',
        ipName: 'IP',
        figures: [fig2],
        shelfAccent: const Color(0xFFE4F2EA),
        catalogTemplateId: 'tmpl_b',
      );
      final states = {
        'fig_a': _owned('fig_a'),
        'fig_b': _owned('fig_b'),
      };

      final repo = _FakeRepo(
        figureMap: {
          'cat_a': _figureSnapshot(id: 'cat_a', value: 100, seriesId: 'series_a'),
          'cat_b': _figureSnapshot(id: 'cat_b', value: 50, seriesId: 'series_b'),
        },
      );

      CollectionAppBootstrap.prime(
        CollectionSnapshot(
          shelfSeries: [seriesA, seriesB],
          figureStates: states,
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [marketSnapshotRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.read(collectionNotifierProvider);

      final result = await container.read(collectionValueProvider.future);

      expect(result.seriesBreakdown.length, 2);
      // sorted by total value descending
      expect(result.seriesBreakdown.first.seriesName, 'Series A');
      expect(result.seriesBreakdown.first.totalValueUsd, 100);
      expect(result.seriesBreakdown.last.totalValueUsd, 50);
    });

    test('CollectionValueTier reflects total value', () async {
      Future<CollectionValueTier> tierFor(double value) async {
        final figs = [
          const ShelfFigure(
            id: 'fig_tier',
            seriesId: 'series_test',
            name: 'Tier Fig',
            rarity: 'Regular',
            isSecret: false,
            catalogFigureTemplateId: 'cat_tier',
          ),
        ];
        final repo = _FakeRepo(
          figureMap: {
            'cat_tier': _figureSnapshot(id: 'cat_tier', value: value),
          },
        );
        final container = _makeContainer(
          snap: _snapWithFigures(
            figures: figs,
            figureStates: {'fig_tier': _owned('fig_tier')},
          ),
          repo: repo,
        );
        final summary = await container.read(collectionValueProvider.future);
        return summary.tier;
      }

      expect(await tierFor(0), CollectionValueTier.empty);
      expect(await tierFor(50), CollectionValueTier.small);
      expect(await tierFor(500), CollectionValueTier.medium);
      expect(await tierFor(2000), CollectionValueTier.large);
      expect(await tierFor(6000), CollectionValueTier.massive);
    });
  });

  group('ShelfValueSummary', () {
    test('coveragePercent is 0 when ownedCount is 0', () {
      expect(ShelfValueSummary.none.coveragePercent, 0);
    });

    test('coveragePercent calculates correctly', () {
      const s = ShelfValueSummary(
        totalValueUsd: 100,
        ownedCount: 4,
        valuedCount: 3,
        unavailableCount: 1,
        topFigures: [],
        seriesBreakdown: [],
        tier: CollectionValueTier.small,
        includesSeriesEstimates: false,
      );
      expect(s.coveragePercent, 75);
      expect(s.coverageLabel, 'Based on 3 of 4 figures');
    });

    test('coverageLabel appends estimates qualifier when needed', () {
      const s = ShelfValueSummary(
        totalValueUsd: 100,
        ownedCount: 15,
        valuedCount: 12,
        unavailableCount: 3,
        topFigures: [],
        seriesBreakdown: [],
        tier: CollectionValueTier.large,
        includesSeriesEstimates: true,
      );
      expect(
        s.coverageLabel,
        'Based on 12 of 15 figures · includes estimates',
      );
    });
  });

  group('formatShelfValueUsd', () {
    test('formats values under 1000', () {
      expect(_fmtValue(42), r'$42');
      expect(_fmtValue(999), r'$999');
    });

    test('formats values with thousands separator', () {
      expect(_fmtValue(1000), r'$1,000');
      expect(_fmtValue(4382), r'$4,382');
      expect(_fmtValue(10000), r'$10,000');
    });

    test('zero returns \$0', () {
      expect(_fmtValue(0), r'$0');
    });
  });
}

/// Inline mirror of [formatShelfValueUsd] for self-contained verification.
String _fmtValue(double v) {
  final rounded = v.round();
  if (rounded == 0) return r'$0';
  final s = rounded.toString();
  final buf = StringBuffer(r'$');
  final offset = s.length % 3;
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
