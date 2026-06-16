import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('marketSnapshotProvider', () {
    tearDown(CatalogBundleCache.resetForTest);

    test('returns figure snapshot when present', () async {
      final figureSnapshot = _figureSnapshot(
        id: 'fig_lucky',
        seriesId: 'series_big_energy',
      );

      final container = _container(
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: figureSnapshot,
        ),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        marketSnapshotProvider('fig_lucky').future,
      );

      expect(result, same(figureSnapshot));
      expect(result?.isSeriesEstimate, isFalse);
    });

    test('falls back to series snapshot via catalog lookup', () async {
      final seriesSnapshot = _seriesSnapshot(
        id: 'series_big_energy',
      );

      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [
            _catalogFigure(
              id: 'fig_lucky',
              seriesId: 'series_big_energy',
            ),
          ],
        ),
      );

      final container = _container(
        repository: _FakeMarketSnapshotRepository(
          seriesSnapshot: seriesSnapshot,
        ),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        marketSnapshotProvider('fig_lucky').future,
      );

      expect(result, same(seriesSnapshot));
      expect(result?.isSeriesEstimate, isTrue);
    });

    test('returns null when figure and series snapshots are missing', () async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [
            _catalogFigure(
              id: 'fig_lucky',
              seriesId: 'series_big_energy',
            ),
          ],
        ),
      );

      final container = _container(
        repository: const _FakeMarketSnapshotRepository(),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        marketSnapshotProvider('fig_lucky').future,
      );

      expect(result, isNull);
    });

    test('returns null when figure is not in catalog for series fallback', () async {
      final container = _container(
        repository: const _FakeMarketSnapshotRepository(),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        marketSnapshotProvider('fig_unknown').future,
      );

      expect(result, isNull);
    });
  });

  group('MarketSnapshotBadge', () {
    testWidgets('figure snapshot shows market value heading and sales', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketSnapshotBadge(
              snapshot: _figureSnapshot(
                id: 'fig_lucky',
                seriesId: 'series_big_energy',
                trend: MarketTrend.unknown,
                recentSalesCount: 18,
                estimatedValueUsd: 42,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Market Value'), findsOneWidget);
      expect(find.text('\$42'), findsOneWidget);
      expect(find.text('18 sales'), findsOneWidget);
    });

    testWidgets('figure snapshot does not show series estimate chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketSnapshotBadge(
              snapshot: _figureSnapshot(
                id: 'fig_lucky',
                seriesId: 'series_big_energy',
                trend: MarketTrend.rising,
                recentSalesCount: 18,
                estimatedValueUsd: 42,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Market Value'), findsOneWidget);
      expect(find.textContaining('Series Estimate'), findsNothing);
    });

    testWidgets('low confidence sales line has no asterisk', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketSnapshotBadge(
              snapshot: _figureSnapshot(
                id: 'fig_lucky',
                seriesId: 'series_big_energy',
                confidence: SnapshotConfidence.low,
                recentSalesCount: 4,
                estimatedValueUsd: 42,
              ),
            ),
          ),
        ),
      );

      expect(find.text('4 sales'), findsOneWidget);
      expect(find.text('4 sales*'), findsNothing);
    });
  });
}

ProviderContainer _container({
  required MarketSnapshotRepository repository,
}) {
  return ProviderContainer(
    overrides: [
      marketSnapshotRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

MarketSnapshot _figureSnapshot({
  required String id,
  required String seriesId,
  MarketTrend trend = MarketTrend.unknown,
  SnapshotConfidence confidence = SnapshotConfidence.high,
  int recentSalesCount = 18,
  double estimatedValueUsd = 42,
}) {
  return MarketSnapshot(
    id: id,
    level: SnapshotLevel.figure,
    figureId: id,
    seriesId: seriesId,
    estimatedValueUsd: estimatedValueUsd,
    trend: trend,
    confidence: confidence,
    recentSalesCount: recentSalesCount,
    computedAt: DateTime.utc(2026, 6, 14),
  );
}

MarketSnapshot _seriesSnapshot({
  required String id,
}) {
  return MarketSnapshot(
    id: id,
    level: SnapshotLevel.series,
    seriesId: id,
    estimatedValueUsd: 28,
    trend: MarketTrend.unknown,
    confidence: SnapshotConfidence.low,
    recentSalesCount: 5,
    computedAt: DateTime.utc(2026, 6, 14),
  );
}

CatalogFigure _catalogFigure({
  required String id,
  required String seriesId,
}) {
  return CatalogFigure(
    id: id,
    seriesId: seriesId,
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    displayName: 'Lucky',
    isSecret: false,
    sortOrder: 1,
    imageKey: id,
  );
}

class _FakeMarketSnapshotRepository implements MarketSnapshotRepository {
  const _FakeMarketSnapshotRepository({
    this.figureSnapshot,
    this.seriesSnapshot,
  });

  final MarketSnapshot? figureSnapshot;
  final MarketSnapshot? seriesSnapshot;

  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) async {
    return figureSnapshot;
  }

  @override
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId) async {
    return seriesSnapshot;
  }

  @override
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId) async {
    return const [];
  }
}
