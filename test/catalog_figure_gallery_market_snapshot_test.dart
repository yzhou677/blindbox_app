import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_badge.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _figureId = 'the_monsters_big_into_energy_vinyl_plush_pendant_luck';
const _seriesId = 'the_monsters_big_into_energy_vinyl_plush_pendant';

void main() {
  group('CatalogFigureGallerySheet market information accordion', () {
    tearDown(CatalogBundleCache.resetForTest);

    testWidgets('collapsed shows disclosure row only when snapshot exists',
        (tester) async {
      await _pumpGallery(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: false)),
        findsOneWidget,
      );
      expect(find.text('Market Value · \$42 · 18 sales'), findsNothing);
      expect(find.text('Luck'), findsOneWidget);
      expect(find.byType(MarketSnapshotBadge), findsNothing);
      expect(find.textContaining('Updated'), findsNothing);

      final nameY = tester.getTopLeft(find.text('Luck')).dy;
      final disclosureY = tester.getTopLeft(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: false)),
      ).dy;
      final seriesY =
          tester.getTopLeft(find.textContaining('Big into Energy')).dy;
      expect(disclosureY, greaterThan(nameY));
      expect(seriesY, greaterThan(disclosureY));
    });

    testWidgets('series fallback collapsed shows disclosure row only',
        (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_catalogFigure()],
        ),
      );

      await _pumpGallery(
        tester,
        repository: _FakeMarketSnapshotRepository(
          seriesSnapshot: _seriesSnapshot(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: false)),
        findsOneWidget,
      );
      expect(
        find.text('Series Avg. · \$37 · 4 sales'),
        findsNothing,
      );
      expect(find.byType(MarketSnapshotBadge), findsNothing);
    });

    testWidgets('renders nothing when snapshot is null', (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_catalogFigure()],
        ),
      );

      await _pumpGallery(
        tester,
        repository: const _FakeMarketSnapshotRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Market Information'), findsNothing);
      expect(find.textContaining('Market Value'), findsNothing);
      expect(find.textContaining('Series Estimate'), findsNothing);
      expect(find.text('Luck'), findsOneWidget);
    });

    testWidgets('watches provider for current gallery figure id', (tester) async {
      const hopeId = 'the_monsters_big_into_energy_vinyl_plush_pendant_hope';

      await _pumpGallery(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshots: {
            hopeId: MarketSnapshot(
              id: hopeId,
              level: SnapshotLevel.figure,
              figureId: hopeId,
              seriesId: _seriesId,
              estimatedValueUsd: 55,
              trend: MarketTrend.unknown,
              confidence: SnapshotConfidence.high,
              recentSalesCount: 9,
              computedAt: DateTime.utc(2026, 6, 15),
            ),
          },
        ),
        items: const [
          CatalogFigureGalleryItem(
            id: hopeId,
            name: 'Hope',
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: false)),
        findsOneWidget,
      );
      expect(find.text('Hope'), findsOneWidget);
    });

    testWidgets('tapping disclosure expands summary and secondary details',
        (tester) async {
      await _pumpGallery(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
      );
      await tester.pumpAndSettle();

      final disclosure = find.text(
        formatMarketSnapshotDiscoverDisclosureLabel(expanded: false),
      );
      await tester.tap(disclosure);
      await tester.pumpAndSettle();

      expect(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: true)),
        findsOneWidget,
      );
      expect(find.text('Market Value · \$42 · 18 sales'), findsOneWidget);
      expect(find.text('\$42'), findsNothing);
      expect(find.text('18 recent sales'), findsNothing);
      expect(find.text('\$38–\$48'), findsOneWidget);
      expect(find.textContaining('Updated'), findsOneWidget);
      expect(find.byType(MarketSnapshotBadge), findsNothing);
    });

    testWidgets('tapping disclosure again collapses inline details',
        (tester) async {
      await _pumpGallery(
        tester,
        repository: _FakeMarketSnapshotRepository(
          figureSnapshot: _figureSnapshot(),
        ),
      );
      await tester.pumpAndSettle();

      final disclosure = find.text(
        formatMarketSnapshotDiscoverDisclosureLabel(expanded: false),
      );
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.text('Market Value · \$42 · 18 sales'), findsOneWidget);

      await tester.tap(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Market Value · \$42 · 18 sales'), findsNothing);
      expect(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: false)),
        findsOneWidget,
      );
    });

    testWidgets('series fallback expanded shows summary line and range',
        (tester) async {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_catalogFigure()],
        ),
      );

      await _pumpGallery(
        tester,
        repository: _FakeMarketSnapshotRepository(
          seriesSnapshot: _seriesSnapshot(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(formatMarketSnapshotDiscoverDisclosureLabel(expanded: false)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Series Avg. · \$37 · 4 sales'),
        findsOneWidget,
      );
      expect(find.text('4 recent sales'), findsNothing);
      expect(find.text('\$37'), findsNothing);
      expect(find.text('\$30–\$45'), findsOneWidget);
    });
  });
}

Future<void> _pumpGallery(
  WidgetTester tester, {
  required MarketSnapshotRepository repository,
  List<CatalogFigureGalleryItem>? items,
  int initialIndex = 0,
}) async {
  final galleryItems = items ??
      const [
        CatalogFigureGalleryItem(
          id: _figureId,
          name: 'Luck',
          rarityLabel: 'Common',
        ),
      ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketSnapshotRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CatalogFigureGallerySheet(
            items: galleryItems,
            initialIndex: initialIndex,
            seriesTitle: 'Big into Energy',
          ),
        ),
      ),
    ),
  );
}

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
    computedAt: DateTime.utc(2026, 6, 15),
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
    computedAt: DateTime.utc(2026, 6, 15),
  );
}

CatalogFigure _catalogFigure() {
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

class _FakeMarketSnapshotRepository implements MarketSnapshotRepository {
  const _FakeMarketSnapshotRepository({
    this.figureSnapshot,
    this.seriesSnapshot,
    this.figureSnapshots = const {},
  });

  final MarketSnapshot? figureSnapshot;
  final MarketSnapshot? seriesSnapshot;
  final Map<String, MarketSnapshot> figureSnapshots;

  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) async {
    if (figureSnapshots.isNotEmpty) {
      return figureSnapshots[figureId];
    }
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
