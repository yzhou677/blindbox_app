import 'dart:async';

import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/market/application/market_listing_lookup.dart';
import 'package:blindbox_app/features/market_intel/application/market_listing_insights.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:blindbox_app/features/market_intel/presentation/market_insights_screen.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_detail_insights_section.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_insights_navigation_row.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_series_average_info_sheet.dart';
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
  MarketListing? listing,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketSnapshotRepositoryProvider.overrideWithValue(repository),
        marketListingByIdProvider(_listingId).overrideWith(
          (ref) => listing ?? _luckListing(),
        ),
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
  String figureId = _figureId,
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
              figureId: figureId,
              listingPriceUsd: listingPriceUsd,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settleInsightsScreen(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Market Value').evaluate().isNotEmpty ||
        find.text(kMarketDetailInsightsUnavailable).evaluate().isNotEmpty) {
      return;
    }
  }
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
    setUp(() {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_luckCatalogSeries()],
          figures: [_luckCatalogFigure()],
        ),
      );
    });

    testWidgets('figure snapshot shows collector-focused layout', (tester) async {
      await _pumpInsightsScreen(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
        figureId: _figureId,
      );
      await _settleInsightsScreen(tester);

      expect(find.text(kMarketInsightsScreenTitle), findsOneWidget);
      expect(find.text('Luck'), findsOneWidget);
      expect(find.text('THE MONSTERS Big Into Energy'), findsOneWidget);
      expect(find.text('Market Value'), findsOneWidget);
      expect(find.text('Current Listing'), findsOneWidget);
      expect(find.text('\$42'), findsNWidgets(2));
      expect(find.text('≈ At market'), findsOneWidget);
      expect(find.text('18 recent sales · Trending'), findsOneWidget);
      expect(find.text('18 recent sales'), findsNothing);
      expect(find.text('Trending'), findsNothing);
      expect(find.text('Range \$38–\$48'), findsOneWidget);
      expect(find.textContaining('Updated'), findsOneWidget);
      expect(find.text('Data Source'), findsOneWidget);
      expect(find.text(kMarketInsightsDataSourceValue), findsOneWidget);
      expect(find.text(kMarketInsightsScreenFooter), findsOneWidget);
      expect(find.text('Recent Sales'), findsNothing);
      expect(find.text(kMarketSnapshotInsightsSeriesLevelEstimateLabel), findsNothing);
    });

    testWidgets('series fallback shows series-level estimate once', (tester) async {
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
      await _settleInsightsScreen(tester);

      expect(
        find.text(kMarketSnapshotInsightsSeriesLevelEstimateLabel),
        findsOneWidget,
      );
      expect(find.text(kMarketSnapshotSeriesAvgLabel), findsOneWidget);
      expect(find.text('Market Value'), findsNothing);
      expect(find.text('\$37'), findsOneWidget);
      expect(find.text('Current Listing'), findsOneWidget);
      expect(find.text('▲ 14% above series avg.'), findsOneWidget);
      expect(find.text('4 recent sales · Stable'), findsOneWidget);
      expect(find.text('4 recent sales'), findsNothing);
      expect(find.text('Stable'), findsNothing);
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
      await _settleInsightsScreen(tester);

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

    testWidgets('shows series estimate above series avg delta', (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_hopeCatalogFigure()],
        ),
      );

      await _pumpPriceDelta(
        tester,
        repository: _FakeMarketSnapshotRepository(
          seriesSnapshot: _seriesSnapshot(),
        ),
        listingPriceUsd: 40,
        figureId: _hopeFigureId,
      );
      await _settleInsightsLoaded(tester, waitFor: '▲ 8% above series avg.');

      expect(find.text('▲ 8% above series avg.'), findsOneWidget);
    });

    testWidgets('hides info icon for figure snapshot delta', (tester) async {
      await _pumpPriceDelta(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
        listingPriceUsd: 48,
      );
      await _settleInsightsLoaded(tester, waitFor: '▲ 14% above market');

      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(
        find.bySemanticsLabel(kMarketSeriesAverageInfoSemanticsLabel),
        findsNothing,
      );
    });

    testWidgets('shows info icon for series estimate delta', (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_hopeCatalogFigure()],
        ),
      );

      await _pumpPriceDelta(
        tester,
        repository: _FakeMarketSnapshotRepository(
          seriesSnapshot: _seriesSnapshot(),
        ),
        listingPriceUsd: 40,
        figureId: _hopeFigureId,
      );
      await _settleInsightsLoaded(tester, waitFor: '▲ 8% above series avg.');

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(
        find.bySemanticsLabel(kMarketSeriesAverageInfoSemanticsLabel),
        findsOneWidget,
      );
    });

    testWidgets('tap series estimate info icon opens disclosure sheet',
        (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_hopeCatalogFigure()],
        ),
      );

      await _pumpPriceDelta(
        tester,
        repository: _FakeMarketSnapshotRepository(
          seriesSnapshot: _seriesSnapshot(),
        ),
        listingPriceUsd: 40,
        figureId: _hopeFigureId,
      );
      await _settleInsightsLoaded(tester, waitFor: '▲ 8% above series avg.');

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text(kMarketSeriesAverageInfoSheetTitle), findsWidgets);
      expect(
        find.textContaining(
          'This comparison uses marketplace activity from the same series',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'regular figures, popular figures, and secrets can sell for very different prices',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('individual figures can vary significantly'),
        findsNothing,
      );
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
      await _settleInsightsScreen(tester);

      expect(find.text(kMarketDetailInsightsHeading), findsNothing);
    });

    testWidgets('shows navigation row for figure snapshot', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketSnapshotRepositoryProvider.overrideWithValue(
              _FakeMarketSnapshotRepository(figureSnapshot: _figureSnapshot()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MarketInsightsNavigationEntry(
                figureId: _figureId,
                listingId: _listingId,
              ),
            ),
          ),
        ),
      );
      await _settleInsightsLoaded(tester, waitFor: kMarketDetailInsightsHeading);

      expect(find.text(kMarketDetailInsightsHeading), findsOneWidget);
    });

    testWidgets('hides navigation row for series estimate', (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_hopeCatalogFigure()],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketSnapshotRepositoryProvider.overrideWithValue(
              _FakeMarketSnapshotRepository(seriesSnapshot: _seriesSnapshot()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Column(
                children: [
                  MarketListingPriceDeltaLine(
                    figureId: _hopeFigureId,
                    listingPriceUsd: 40,
                  ),
                  MarketInsightsNavigationEntry(
                    figureId: _hopeFigureId,
                    listingId: _listingId,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settleInsightsLoaded(tester, waitFor: '▲ 8% above series avg.');

      expect(find.text('▲ 8% above series avg.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text(kMarketDetailInsightsHeading), findsNothing);
    });
  });
}

CatalogFigure _luckCatalogFigure() {
  return CatalogFigure(
    id: _figureId,
    seriesId: _seriesId,
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    displayName: 'Luck',
    isSecret: false,
    sortOrder: 1,
    imageKey: _figureId,
  );
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

MarketListing _luckListing() {
  return MarketListing(
    id: _listingId,
    collectible: Collectible(
      id: 'c-$_listingId',
      name: 'Luck',
      series: 'THE MONSTERS Big into Energy Series-Vinyl Plush Pendant Blind Box',
      brand: 'POP MART',
      releaseDate: DateTime.utc(2025, 4, 25),
      imageUrl: '',
    ),
    currentPriceUsd: 42,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

CatalogSeries _luckCatalogSeries() {
  return CatalogSeries(
    id: _seriesId,
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    displayName: 'THE MONSTERS Big Into Energy',
    releaseDate: '2025-04-25',
    isBlindBox: true,
    imageKey: _seriesId,
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
