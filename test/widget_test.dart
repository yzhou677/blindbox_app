import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';

List<Override> _blindboxTestOverrides() => [
  catalogBundleProvider.overrideWith(
    (_) async =>
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
  ),
  homeFeedSnapshotProvider.overrideWith(
    (_) async => HomeFeedSnapshot(
      latest: mockSeriesReleases,
      trending: mockSeriesReleases.skip(1).take(4).toList(growable: false),
    ),
  ),
  officialFeedCatalogProvider.overrideWith(
    (_) async => OfficialFeedCatalog.empty,
  ),
  seriesReleaseLookupProvider.overrideWithValue(mockSeriesReleaseByDropId),
];

final class EmptyTestCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot.emptyTest();
}

final class SeededTestCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() {
    const seriesId = 'series_hirono_other_one';
    final series = ShelfSeries(
      id: seriesId,
      name: 'The Other One',
      brand: 'POP MART',
      ipName: 'Hirono',
      figures: const [
        ShelfFigure(
          id: 'fig_hirono_1',
          seriesId: seriesId,
          name: 'The Fox',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_2',
          seriesId: seriesId,
          name: 'The Bird',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_3',
          seriesId: seriesId,
          name: 'The Star',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_4',
          seriesId: seriesId,
          name: 'The Poem',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_5',
          seriesId: seriesId,
          name: 'The Secret',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_6',
          seriesId: seriesId,
          name: 'The Chase',
          rarity: 'Secret',
          isSecret: true,
        ),
      ],
      shelfAccent: const Color(0xFFF2E8DC),
      catalogTemplateId: 'series-hirono-other-one',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'hirono',
    );

    return CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {
        'fig_hirono_1': TrackedFigure(
          figureId: 'fig_hirono_1',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_2': TrackedFigure(
          figureId: 'fig_hirono_2',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_3': TrackedFigure(
          figureId: 'fig_hirono_3',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_4': TrackedFigure(
          figureId: 'fig_hirono_4',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_5': TrackedFigure(
          figureId: 'fig_hirono_5',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_6': TrackedFigure(
          figureId: 'fig_hirono_6',
          state: FigureCollectionState.wishlist,
        ),
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    CatalogBundleCache.resetForTest();
    CatalogBundleCache.prime(
      const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
    );
    // [appRouter] is a process-wide singleton; reset the shell tab between tests.
    appRouter.go('/collection');
  });

  tearDown(CatalogBundleCache.resetForTest);

  testWidgets('App shell opens on Collection tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('My collection'), findsWidgets);
    expect(find.text('Collection'), findsWidgets);
  });

  testWidgets('Discover tab shows home feed', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byIcon(Symbols.explore_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Latest drops'), findsOneWidget);
    expect(find.text('Moon Mischief'), findsOneWidget);
    expect(find.text('Trending series'), findsOneWidget);
  });

  testWidgets('Collection tab shows series-first shelf and summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._blindboxTestOverrides(),
          collectionNotifierProvider.overrideWith(
            SeededTestCollectionNotifier.new,
          ),
        ],
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('My collection'), findsWidgets);
    expect(
      find.byKey(const Key('collection_insights_compact_glance')),
      findsOneWidget,
    );
    expect(find.text('5'), findsOneWidget);
    expect(
      find.byKey(const Key('collection_header_add_series')),
      findsOneWidget,
    );
    // Brand/IP filters live in the Filters sheet (not always-visible chip rails).
    await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('POP MART'), findsWidgets);
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Completed series are collapsed by default — expand before asserting card text.
    for (var i = 0; i < 4; i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -400),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Completed (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('The Other One'), findsOneWidget);

    // Apply brand filter via the Filters sheet.
    await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('POP MART'));
    await tester.tap(find.text('POP MART'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('The Other One'), findsOneWidget);

    // Clear brand selection via Filters sheet (no always-visible "All Brands" chip).
    await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('filters_sheet_clear_all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('The Other One'), findsOneWidget);
  });

  testWidgets('Add series sheet dismisses when leaving Collection tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._blindboxTestOverrides(),
          collectionNotifierProvider.overrideWith(
            SeededTestCollectionNotifier.new,
          ),
        ],
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('collection_header_add_series')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.explore_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsNothing);

    await tester.tap(find.text('Collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsNothing);
    expect(find.text('My collection'), findsWidgets);

    // Flush catalog background refresh timer started by Add sheet.
    await tester.pump(const Duration(seconds: 13));
  });

  testWidgets('Market tab shows search and browse filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Market'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Chasers'), findsNothing);
    expect(find.text('Collectibles'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    await tester.tap(find.text('POP MART'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('THE MONSTERS'), findsWidgets);
  });

  testWidgets('Collection empty state is polished', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            EmptyTestCollectionNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Empty shelf'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });
}
