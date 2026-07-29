import 'package:blindbox_app/core/search/search_commit_policy.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/widgets/collection_page_segment_control.dart';
import 'package:blindbox_app/features/collection/widgets/collection_wishlist_page.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/widgets/search_field_clear_suffix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _FixedCollectionNotifier extends CollectionNotifier {
  _FixedCollectionNotifier(this._fixed);
  final CollectionSnapshot _fixed;

  @override
  CollectionSnapshot build() => _fixed;
}

Finder get _searchField => find.descendant(
  of: find.byType(AppSearchField),
  matching: find.byType(TextField),
);

CollectionSnapshot _shelfSnap() => CollectionSnapshot(
  shelfSeries: [
    testShelfSeries(id: 'a', name: 'Alpha Series'),
    testShelfSeries(id: 'b', name: 'Bravo Series'),
    testShelfSeries(id: 's', name: 'Skullpanda Series'),
  ],
  figureStates: const {},
);

CollectionSnapshot _shelfAndWishlistSnap() {
  return CollectionSnapshot(
    shelfSeries: [
      testShelfSeries(id: 'a', name: 'Alpha Series'),
      testShelfSeries(id: 'b', name: 'Bravo Series'),
    ],
    figureStates: const {},
    seriesWishlist: const [
      WishlistedCatalogSeries(
        catalogSeriesId: 'wish_s',
        name: 'Wishlist Skullpanda',
        brand: 'POP MART',
        ipName: 'SKULLPANDA',
        imageKey: 'wish_s',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'skullpanda',
        addedAtMicros: 1,
      ),
    ],
  );
}

Future<void> _pumpCollectionScreen(
  WidgetTester tester, {
  required CollectionSnapshot snap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _FixedCollectionNotifier(snap),
        ),
        collectionShelfUiPrefsProvider.overrideWith(
          CollectionShelfUiPrefsNotifier.new,
        ),
        catalogBundleProvider.overrideWith(
          (ref) async => const CatalogSeedBundle(
            brands: [],
            ips: [],
            series: [],
            figures: [],
          ),
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
}

void _resetCounters() {
  CollectionScreen.debugCommittedQueryCount = 0;
  CollectionScreen.debugShelfCommittedQueryCount = 0;
  CollectionScreen.debugWishlistCommittedQueryCount = 0;
  CollectionScreen.debugShelfCommittedQuery = '';
  CollectionScreen.debugWishlistCommittedQuery = '';
  CollectionScreen.debugBuildCount = 0;
  CollectionScreen.debugOnSearchChangedCount = 0;
  CollectionScreen.debugBrandFilterCount = 0;
  CollectionScreen.debugIpFilterCount = 0;
  CollectionScreen.debugPartitionCount = 0;
  CollectionScreen.debugSortCount = 0;
  ShelfBrowseSearchMatchCache.debugSearchExecutionCount = 0;
  ShelfBrowseSearchMatchCache.debugCacheHitCount = 0;
  CollectionWishlistPage.debugBuildCount = 0;
  CollectionWishlistPage.debugFilterCount = 0;
  SearchFieldClearSuffix.debugListenerFireCount = 0;
  SearchFieldClearSuffix.debugVisibilityRebuildCount = 0;
  AppSearchField.debugBuildCount = 0;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _resetCounters();
  });

  testWidgets('visible text updates immediately without page rebuild', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester, snap: _shelfSnap());
    _resetCounters();

    await tester.enterText(_searchField, 's');
    await tester.pump();

    expect(find.text('s'), findsOneWidget);
    expect(CollectionScreen.debugBuildCount, 0);
    expect(CollectionScreen.debugCommittedQueryCount, 0);
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
  });

  testWidgets(
    'ten non-empty characters: one clear-suffix transition; no page rebuild',
    (tester) async {
      await _pumpCollectionScreen(tester, snap: _shelfSnap());
      _resetCounters();

      var typed = '';
      for (final ch in 'skullpanda'.split('')) {
        typed += ch;
        await tester.enterText(_searchField, typed);
        await tester.pump();
      }

      expect(find.text('skullpanda'), findsOneWidget);
      expect(CollectionScreen.debugOnSearchChangedCount, 10);
      expect(CollectionScreen.debugBuildCount, 0);
      expect(CollectionScreen.debugCommittedQueryCount, 0);
      expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
      expect(SearchFieldClearSuffix.debugVisibilityRebuildCount, 1);
      expect(
        SearchFieldClearSuffix.debugListenerFireCount,
        greaterThanOrEqualTo(10),
      );
    },
  );

  testWidgets('no shelf filter before commit; one filter after settle', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester, snap: _shelfSnap());
    _resetCounters();

    await tester.enterText(_searchField, 'Alpha');
    await tester.pump();
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
    expect(CollectionScreen.debugCommittedQueryCount, 0);
    expect(find.text('No series match your search.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 249));
    expect(CollectionScreen.debugCommittedQueryCount, 0);
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(CollectionScreen.debugCommittedQueryCount, 1);
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 1);
    expect(find.text('No series match your search.'), findsNothing);
  });

  testWidgets('rapid typing commits only the latest query once', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester, snap: _shelfSnap());
    _resetCounters();

    var typed = '';
    for (final ch in 'Alpha'.split('')) {
      typed += ch;
      await tester.enterText(_searchField, typed);
      await tester.pump();
      expect(CollectionScreen.debugCommittedQueryCount, 0);
    }

    await tester.pump(SearchCommitPolicy.localCollection);
    await tester.pump();

    expect(CollectionScreen.debugCommittedQueryCount, 1);
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 1);
  });

  testWidgets('clear commits shelf filter immediately', (tester) async {
    await _pumpCollectionScreen(tester, snap: _shelfSnap());

    await tester.enterText(_searchField, 'Alpha');
    await tester.pump(); // flush post-frame schedule
    await tester.pump(SearchCommitPolicy.localCollection);
    await tester.pump();
    expect(CollectionScreen.debugCommittedQueryCount, greaterThan(0));
    expect(find.text('No series match your search.'), findsNothing);

    final beforeClear = CollectionScreen.debugCommittedQueryCount;
    final buildsBefore = CollectionScreen.debugBuildCount;
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(CollectionScreen.debugCommittedQueryCount, beforeClear + 1);
    expect(CollectionScreen.debugBuildCount, greaterThan(buildsBefore));
    expect(find.text('No series match your search.'), findsNothing);
    expect(find.byTooltip('Clear'), findsNothing);
  });

  testWidgets(
    'wishlist typing does not run shelf filter; wishlist filters after commit',
    (tester) async {
      await _pumpCollectionScreen(tester, snap: _shelfAndWishlistSnap());
      await tester.tap(find.text('Wishlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      _resetCounters();

      var typed = '';
      for (final ch in 'Skull'.split('')) {
        typed += ch;
        await tester.enterText(_searchField, typed);
        await tester.pump();
      }

      expect(find.text('Skull'), findsOneWidget);
      expect(CollectionScreen.debugBuildCount, 0);
      expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
      expect(CollectionScreen.debugCommittedQueryCount, 0);
      final wishlistFiltersBefore = CollectionWishlistPage.debugFilterCount;

      await tester.pump(SearchCommitPolicy.localCollection);
      await tester.pump();

      expect(CollectionScreen.debugCommittedQueryCount, 1);
      expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
      expect(
        CollectionWishlistPage.debugFilterCount,
        greaterThan(wishlistFiltersBefore),
      );
      expect(find.textContaining('Wishlist Skullpanda'), findsOneWidget);
    },
  );

  testWidgets(
    'switching Shelf to Wishlist keeps independent live text and commits',
    (tester) async {
      await _pumpCollectionScreen(tester, snap: _shelfAndWishlistSnap());

      await tester.enterText(_searchField, 'Alpha');
      await tester.pump();
      await tester.pump(SearchCommitPolicy.localCollection);
      await tester.pump();
      expect(CollectionScreen.debugShelfCommittedQueryCount, greaterThan(0));
      expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');
      expect(find.text('No series match your search.'), findsNothing);

      await tester.tap(find.text('Wishlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CollectionWishlistPage), findsOneWidget);
      // Shelf query must not paint into the Wishlist field.
      expect(find.text('Alpha'), findsNothing);
      expect(CollectionScreen.debugWishlistCommittedQuery, isEmpty);

      _resetCounters();
      await tester.enterText(_searchField, 'Wishlist');
      await tester.pump();
      expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);

      await tester.pump(SearchCommitPolicy.localCollection);
      await tester.pump();
      expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
      expect(CollectionScreen.debugWishlistCommittedQueryCount, 1);
      expect(CollectionScreen.debugShelfCommittedQueryCount, 0);
      expect(CollectionScreen.debugWishlistCommittedQuery, 'Wishlist');
      expect(find.textContaining('Wishlist Skullpanda'), findsOneWidget);
    },
  );

  testWidgets('policy timings: collection 250ms; catalog 250ms; market 400ms', (
    tester,
  ) async {
    expect(
      SearchCommitPolicy.localCollection,
      const Duration(milliseconds: 250),
    );
    expect(SearchCommitPolicy.localCatalog, const Duration(milliseconds: 250));
    expect(SearchCommitPolicy.remote, const Duration(milliseconds: 400));
  });

  testWidgets(
    'Filter after committed search does not rerun text search',
    (tester) async {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'a',
            name: 'Alpha Series',
            brand: 'POP MART',
            taxonomyBrandId: 'pop_mart',
            ipName: 'Hirono',
            taxonomyIpId: 'hirono',
          ),
          testShelfSeries(
            id: 'b',
            name: 'Bravo Series',
            brand: 'TOP TOY',
            taxonomyBrandId: 'toptoy',
            ipName: 'Hirono',
            taxonomyIpId: 'hirono',
          ),
        ],
        figureStates: const {},
      );
      await _pumpCollectionScreen(tester, snap: snap);

      await tester.enterText(_searchField, 'Alpha');
      await tester.pump();
      await tester.pump(SearchCommitPolicy.localCollection);
      await tester.pump();
      expect(CollectionScreen.debugCommittedQueryCount, greaterThan(0));
      expect(
        ShelfBrowseSearchMatchCache.debugSearchExecutionCount,
        greaterThan(0),
      );

      final searchesAfterCommit =
          ShelfBrowseSearchMatchCache.debugSearchExecutionCount;
      CollectionScreen.debugBrandFilterCount = 0;
      CollectionScreen.debugBuildCount = 0;
      ShelfBrowseSearchMatchCache.debugCacheHitCount = 0;

      await tester.tap(
        find.byKey(const Key('collection_shelf_filters_control')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Collection Attributes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('filters_sheet_has_duplicates')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        ShelfBrowseSearchMatchCache.debugSearchExecutionCount,
        searchesAfterCommit,
      );
      expect(CollectionScreen.debugBrandFilterCount, greaterThan(0));
      expect(ShelfBrowseSearchMatchCache.debugCacheHitCount, greaterThan(0));
      // No owned duplicates in this fixture → filters hide all series.
      expect(find.text('No series match these filters'), findsOneWidget);

      final brandsBeforeReselect = CollectionScreen.debugBrandFilterCount;
      final buildsBeforeReselect = CollectionScreen.debugBuildCount;
      await tester.tap(
        find.byKey(const Key('collection_shelf_filters_control')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(CollectionScreen.debugBrandFilterCount, brandsBeforeReselect);
      expect(CollectionScreen.debugBuildCount, buildsBeforeReselect);
      expect(
        ShelfBrowseSearchMatchCache.debugSearchExecutionCount,
        searchesAfterCommit,
      );
    },
  );

  testWidgets('segment control remains reachable while typing', (tester) async {
    await _pumpCollectionScreen(tester, snap: _shelfSnap());
    await tester.enterText(_searchField, 'Al');
    await tester.pump();
    expect(find.byType(CollectionPageSegmentControl), findsOneWidget);
  });
}
