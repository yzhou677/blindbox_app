import 'dart:async';

import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/market_intel/application/market_listing_insights.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:blindbox_app/features/market_intel/presentation/market_insights_screen.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_detail_insights_section.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_insights_navigation_row.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _figureId = 'the_monsters_big_into_energy_vinyl_plush_pendant_luck';
const _hopeFigureId = 'the_monsters_big_into_energy_vinyl_plush_pendant_hope';
const _seriesId = 'the_monsters_big_into_energy_vinyl_plush_pendant';
const _listingId = 'mkt-insights-fixture';

MarketSnapshot _figureSnapshot() {
  return MarketSnapshot(
    id: _figureId,
    level: SnapshotLevel.figure,
    figureId: _figureId,
    seriesId: _seriesId,
    estimatedValueUsd: 42,
    trend: MarketTrend.rising,
    confidence: SnapshotConfidence.high,
    recentSalesCount: 18,
    priceRangeMinUsd: 38,
    priceRangeMaxUsd: 48,
    computedAt: DateTime.utc(2026, 6, 15, 11),
  );
}

MarketSnapshot _seriesSnapshot() {
  return MarketSnapshot(
    id: _seriesId,
    level: SnapshotLevel.series,
    seriesId: _seriesId,
    estimatedValueUsd: 37,
    trend: MarketTrend.stable,
    confidence: SnapshotConfidence.low,
    recentSalesCount: 4,
    priceRangeMinUsd: 30,
    priceRangeMaxUsd: 45,
    computedAt: DateTime.utc(2026, 6, 15, 11),
  );
}

Future<void> _pumpInsightsScreen(
  WidgetTester tester, {
  required MarketSnapshotRepository repository,
  required String figureId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketSnapshotRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MarketInsightsScreen(
          figureId: figureId,
          listingId: _listingId,
        ),
      ),
    ),
  );
}

Future<void> _pumpPriceDelta(
  WidgetTester tester, {
  required MarketSnapshotRepository repository,
  required double listingPriceUsd,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketSnapshotRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(22),
            child: MarketListingPriceDeltaLine(
              figureId: _figureId,
              listingPriceUsd: listingPriceUsd,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settleInsightsLoaded(
  WidgetTester tester, {
  required String waitFor,
}) async {
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text(waitFor).evaluate().isNotEmpty) return;
  }
}

void main() {
  tearDown(CatalogBundleCache.resetForTest);

  group('MarketInsightsScreen', () {
    testWidgets('figure snapshot shows sectioned insights content', (tester) async {
      await _pumpInsightsScreen(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
        figureId: _figureId,
      );
      await tester.pumpAndSettle();

      expect(find.text(kMarketInsightsScreenTitle), findsOneWidget);
      expect(find.text('Market Value'), findsOneWidget);
      expect(find.text('\$42'), findsOneWidget);
      expect(find.text('Recent Sales'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('Range'), findsOneWidget);
      expect(find.text('\$38–\$48'), findsOneWidget);
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('Data Source'), findsOneWidget);
      expect(find.text(kMarketInsightsDataSourceValue), findsOneWidget);
      expect(find.text(kMarketInsightsScreenFooter), findsOneWidget);
      expect(find.text(kMarketSnapshotDiscoverSeriesFallbackLabel), findsNothing);
    });

    testWidgets('series fallback shows using series estimate once', (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_hopeCatalogFigure()],
        ),
      );

      await _pumpInsightsScreen(
        tester,
        repository: _FakeMarketSnapshotRepository(
          seriesSnapshot: _seriesSnapshot(),
        ),
        figureId: _hopeFigureId,
      );
      await tester.pumpAndSettle();

      expect(find.text(kMarketSnapshotDiscoverSeriesFallbackLabel), findsOneWidget);
      expect(find.text('\$37'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
    });

    testWidgets('loading shows skeleton', (tester) async {
      await _pumpInsightsScreen(
        tester,
        repository: _HangingMarketSnapshotRepository(),
        figureId: _figureId,
      );
      await tester.pump();

      expect(find.text(kMarketDetailInsightsUnavailable), findsNothing);
    });

    testWidgets('error shows unavailable copy', (tester) async {
      await _pumpInsightsScreen(
        tester,
        repository: _ErrorMarketSnapshotRepository(),
        figureId: _figureId,
      );
      await tester.pumpAndSettle();

      expect(find.text(kMarketDetailInsightsUnavailable), findsOneWidget);
    });
  });

  group('MarketInsightsNavigationRow', () {
    testWidgets('shows navigation label without market data', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MarketInsightsNavigationRow(onTap: () => tapped = true),
          ),
        ),
      );

      expect(find.text(kMarketDetailInsightsHeading), findsOneWidget);
      expect(find.text('\$42'), findsNothing);
      expect(find.text('Recent Sales'), findsNothing);
      expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);

      await tester.tap(find.text(kMarketDetailInsightsHeading));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('MarketListingPriceDeltaLine', () {
    testWidgets('shows above market delta', (tester) async {
      await _pumpPriceDelta(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
        listingPriceUsd: 48,
      );
      await _settleInsightsLoaded(tester, waitFor: '▲ 14% above market');

      expect(find.text('▲ 14% above market'), findsOneWidget);
    });

    testWidgets('shows below market delta', (tester) async {
      await _pumpPriceDelta(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
        listingPriceUsd: 35,
      );
      await _settleInsightsLoaded(tester, waitFor: '✓ Below market');

      expect(find.text('✓ Below market'), findsOneWidget);
    });

    testWidgets('shows at market delta', (tester) async {
      await _pumpPriceDelta(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
        listingPriceUsd: 42,
      );
      await _settleInsightsLoaded(tester, waitFor: '≈ At market');

      expect(find.text('≈ At market'), findsOneWidget);
    });
  });

  group('Market detail insights visibility', () {
    testWidgets('hides navigation row when listing has no figure match', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final listing = MarketListing(
                    id: _listingId,
                    collectible: Collectible(
                      id: 'c-$_listingId',
                      name: 'Unknown',
                      series: 'Unknown Series',
                      brand: 'POP MART',
                      releaseDate: DateTime.utc(2026, 3, 20),
                      imageUrl: 'https://example.com/x.png',
                    ),
                    currentPriceUsd: 42,
                    priceChangePercent: 0,
                    listingCount: 1,
                  );
                  final figureId = marketListingInsightsFigureId(listing);
                  if (figureId == null) return const SizedBox.shrink();
                  return MarketInsightsNavigationRow(onTap: () {});
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kMarketDetailInsightsHeading), findsNothing);
    });
  });
}

CatalogFigure _hopeCatalogFigure() {
  return CatalogFigure(
    id: _hopeFigureId,
    seriesId: _seriesId,
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    displayName: 'Hope',
    isSecret: false,
    sortOrder: 2,
    imageKey: _hopeFigureId,
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

class _HangingMarketSnapshotRepository implements MarketSnapshotRepository {
  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) {
    return Completer<MarketSnapshot?>().future;
  }

  @override
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId) {
    return Completer<MarketSnapshot?>().future;
  }

  @override
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId) async {
    return const [];
  }
}

class _ErrorMarketSnapshotRepository implements MarketSnapshotRepository {
  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) async {
    throw StateError('snapshot failed');
  }

  @override
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId) async {
    throw StateError('snapshot failed');
  }

  @override
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId) async {
    throw StateError('snapshot failed');
  }
}
