import 'dart:io';

import 'package:blindbox_app/core/search/search_commit_policy.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_browse_launch.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_browse_screen.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_search_experience.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart'
    show CollectionSnapshot;
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/widgets/feed_search_screen.dart';
import 'package:blindbox_app/shared/widgets/search_field_clear_suffix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogSeedBundle _bundle() {
  const brandId = 'nyota';
  const ipId = 'where_moments_meet_ip';
  const seriesId = 'where_moments_meet';
  return const CatalogSeedBundle(
    brands: [CatalogBrand(id: brandId, displayName: 'Nyota')],
    ips: [
      CatalogIp(id: ipId, brandId: brandId, displayName: 'Where Moments Meet'),
    ],
    series: [
      CatalogSeries(
        id: seriesId,
        brandId: brandId,
        ipId: ipId,
        displayName: 'Where Moments Meet Series Plush Doll',
        releaseDate: '2026-01-01',
        isBlindBox: true,
        imageKey: seriesId,
      ),
    ],
    figures: [
      CatalogFigure(
        id: 'where_moments_meet_fig_1',
        seriesId: seriesId,
        brandId: brandId,
        ipId: ipId,
        displayName: 'Where Moments Meet Plush Doll',
        isSecret: false,
        sortOrder: 0,
        imageKey: 'where_moments_meet_fig_1',
      ),
    ],
  );
}

final class _EmptyCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot.emptyTest();
}

Future<void> _pumpDiscoverSearch(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CatalogBrowseScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void _resetLiveInputCounters() {
  CatalogSearchExperience.debugBuildCount = 0;
  CatalogSearchExperience.debugSearchExecutionCount = 0;
  CatalogSearchExperience.debugOnSearchChangedCount = 0;
  CatalogSearchExperience.debugQueryActiveTrueCount = 0;
  CatalogSearchExperience.debugQueryActiveFalseCount = 0;
  CatalogSearchExperience.debugResultsPaneBuildCount = 0;
  FeedSearchScreen.debugBuildCount = 0;
  AppSearchField.debugBuildCount = 0;
  SearchFieldClearSuffix.debugListenerFireCount = 0;
  SearchFieldClearSuffix.debugVisibilityRebuildCount = 0;
}

Finder get _searchField => find.byType(TextField);

void main() {
  late Directory tempCacheRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _resetLiveInputCounters();
    tempCacheRoot = await Directory.systemTemp.createTemp(
      'discover_search_test_',
    );
    CatalogImageDiskCache.testRootOverride = tempCacheRoot;
    CatalogImageResolver.storageFallbackOverride = false;
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogBundleCache.prime(_bundle());
  });

  tearDown(() async {
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageDiskCache.resetForTest();
    if (await tempCacheRoot.exists()) {
      await tempCacheRoot.delete(recursive: true);
    }
  });

  testWidgets('live text updates immediately without ancestor rebuilds', (
    tester,
  ) async {
    await _pumpDiscoverSearch(tester);
    _resetLiveInputCounters();

    await tester.enterText(_searchField, 's');
    await tester.pump();

    expect(find.text('s'), findsOneWidget);
    expect(CatalogSearchExperience.debugBuildCount, 0);
    expect(FeedSearchScreen.debugBuildCount, 0);
    expect(AppSearchField.debugBuildCount, 0);
    expect(CatalogSearchExperience.debugResultsPaneBuildCount, 0);
    expect(CatalogSearchExperience.debugSearchExecutionCount, 0);
  });

  testWidgets('ten non-empty characters publish at most one queryActive=true', (
    tester,
  ) async {
    await _pumpDiscoverSearch(tester);
    _resetLiveInputCounters();

    var typed = '';
    for (final ch in 'skullpanda'.split('')) {
      typed += ch;
      await tester.enterText(_searchField, typed);
      await tester.pump();
    }

    expect(find.text('skullpanda'), findsOneWidget);
    expect(CatalogSearchExperience.debugOnSearchChangedCount, 10);
    expect(CatalogSearchExperience.debugQueryActiveTrueCount, 1);
    expect(CatalogSearchExperience.debugQueryActiveFalseCount, 0);
    expect(CatalogSearchExperience.debugBuildCount, 0);
    expect(FeedSearchScreen.debugBuildCount, 0);
    expect(CatalogSearchExperience.debugResultsPaneBuildCount, 0);
    expect(CatalogSearchExperience.debugSearchExecutionCount, 0);
    // Clear suffix sees every controller tick but only rebuilds once (empty→text).
    expect(
      SearchFieldClearSuffix.debugListenerFireCount,
      greaterThanOrEqualTo(10),
    );
    expect(SearchFieldClearSuffix.debugVisibilityRebuildCount, 1);
  });

  testWidgets('non-empty to empty publishes one queryActive=false', (
    tester,
  ) async {
    await _pumpDiscoverSearch(tester);
    _resetLiveInputCounters();

    await tester.enterText(_searchField, 'where');
    await tester.pump();
    expect(CatalogSearchExperience.debugQueryActiveTrueCount, 1);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(CatalogSearchExperience.debugQueryActiveFalseCount, 1);
    expect(find.text('Matches'), findsNothing);
  });

  testWidgets('Matches chrome and one search appear together after settle', (
    tester,
  ) async {
    await _pumpDiscoverSearch(tester);
    _resetLiveInputCounters();

    await tester.enterText(_searchField, 'where');
    await tester.pump();
    expect(find.text('Matches'), findsNothing);
    expect(CatalogSearchExperience.debugSearchExecutionCount, 0);

    await tester.pump(const Duration(milliseconds: 249));
    expect(CatalogSearchExperience.debugSearchExecutionCount, 0);
    expect(find.text('Matches'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(CatalogSearchExperience.debugSearchExecutionCount, 1);
    expect(CatalogSearchExperience.debugBuildCount, 1);
    expect(FeedSearchScreen.debugBuildCount, 1);
    expect(CatalogSearchExperience.debugResultsPaneBuildCount, 1);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Where Moments Meet Series Plush Doll'), findsOneWidget);
  });

  testWidgets(
    'rapid typing does not expose empty Matches or rebuild results early',
    (tester) async {
      await _pumpDiscoverSearch(tester);
      _resetLiveInputCounters();

      var typed = '';
      for (final ch in 'where'.split('')) {
        typed += ch;
        await tester.enterText(_searchField, typed);
        await tester.pump();
        expect(find.text('Matches'), findsNothing);
        expect(CatalogSearchExperience.debugResultsPaneBuildCount, 0);
      }

      await tester.pump(SearchCommitPolicy.localCatalog);
      await tester.pump();

      expect(CatalogSearchExperience.debugSearchExecutionCount, 1);
      expect(find.text('Matches'), findsOneWidget);
      expect(find.text('Where Moments Meet Series Plush Doll'), findsOneWidget);
    },
  );

  testWidgets('clear removes Matches immediately', (tester) async {
    await _pumpDiscoverSearch(tester);

    await tester.enterText(_searchField, 'where');
    await tester.pump(); // flush post-frame live schedule
    await tester.pump(SearchCommitPolicy.localCatalog);
    await tester.pump();
    expect(find.text('Matches'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(find.text('Matches'), findsNothing);
    expect(find.text('Where Moments Meet Series Plush Doll'), findsNothing);
  });

  testWidgets('previous committed results stay until next commit', (
    tester,
  ) async {
    await _pumpDiscoverSearch(tester);

    await tester.enterText(_searchField, 'where');
    await tester.pump();
    await tester.pump(SearchCommitPolicy.localCatalog);
    await tester.pump();
    expect(find.text('Where Moments Meet Series Plush Doll'), findsOneWidget);

    final buildsBefore = CatalogSearchExperience.debugBuildCount;
    final resultsBefore = CatalogSearchExperience.debugResultsPaneBuildCount;
    final searchesBefore = CatalogSearchExperience.debugSearchExecutionCount;

    await tester.enterText(_searchField, 'wherex');
    await tester.pump();
    expect(CatalogSearchExperience.debugBuildCount, buildsBefore);
    expect(CatalogSearchExperience.debugResultsPaneBuildCount, resultsBefore);
    expect(CatalogSearchExperience.debugSearchExecutionCount, searchesBefore);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Where Moments Meet Series Plush Doll'), findsOneWidget);

    await tester.pump(SearchCommitPolicy.localCatalog);
    await tester.pump();
    expect(find.text('No matches for that search.'), findsOneWidget);
  });

  testWidgets('Discover camera entry uses shared pre-capture guidance', (
    tester,
  ) async {
    await _pumpDiscoverSearch(tester);

    await tester.tap(find.byKey(const Key('catalog-photo-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Keep the collectible centered and in focus.'),
      findsOneWidget,
    );
    expect(find.text('Open Camera'), findsOneWidget);
  });

  testWidgets('launch prefills initial query from Add Series handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CatalogBrowseScreen(
            launch: CatalogBrowseLaunch(initialQuery: 'where'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('where'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Where Moments Meet Series Plush Doll'), findsOneWidget);
  });
}
