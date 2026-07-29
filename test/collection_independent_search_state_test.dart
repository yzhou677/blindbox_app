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

final class _DefaultShelfUiPrefsNotifier
    extends CollectionShelfUiPrefsNotifier {
  @override
  CollectionShelfUiPrefs build() => const CollectionShelfUiPrefs();
}

Finder get _searchField => find.descendant(
  of: find.byType(AppSearchField),
  matching: find.byType(TextField),
);

ShelfSeries _series({
  required String id,
  required String name,
  String brand = 'POP MART',
  String taxonomyBrandId = 'pop_mart',
  String ipName = 'Hirono',
  String taxonomyIpId = 'hirono',
}) {
  return testShelfSeries(
    id: id,
    name: name,
    brand: brand,
    taxonomyBrandId: taxonomyBrandId,
    ipName: ipName,
    taxonomyIpId: taxonomyIpId,
    figures: [
      ShelfFigure(
        id: '${id}_fig_0',
        seriesId: id,
        name: '$name Figure',
        rarity: 'Regular',
        isSecret: false,
        catalogFigureTemplateId: '${id}_tpl_0',
      ),
    ],
  );
}

CollectionSnapshot _snap() {
  final alpha = _series(id: 'a', name: 'Alpha Series');
  final bravo = _series(
    id: 'b',
    name: 'Bravo Series',
    brand: 'TOP TOY',
    taxonomyBrandId: 'toptoy',
  );
  return CollectionSnapshot(
    shelfSeries: [alpha, bravo],
    // Own one figure so the warm-start banner does not displace chrome.
    figureStates: {
      alpha.figures.first.id: TrackedFigure(
        figureId: alpha.figures.first.id,
        state: FigureCollectionState.owned,
      ),
    },
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
      WishlistedCatalogSeries(
        catalogSeriesId: 'wish_h',
        name: 'Wishlist Hirono',
        brand: 'POP MART',
        ipName: 'Hirono',
        imageKey: 'wish_h',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'hirono',
        addedAtMicros: 2,
      ),
    ],
  );
}

Future<void> _pumpCollectionScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _FixedCollectionNotifier(_snap()),
        ),
        collectionShelfUiPrefsProvider.overrideWith(
          _DefaultShelfUiPrefsNotifier.new,
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

Future<void> _openSegment(WidgetTester tester, String label) async {
  // enterText opens the test keyboard and can push the segment off-screen.
  FocusManager.instance.primaryFocus?.unfocus();
  tester.view.resetViewInsets();
  await tester.pump();

  final segment = find.byType(CollectionPageSegmentControl);
  expect(segment, findsOneWidget);
  await tester.ensureVisible(segment);
  await tester.pump();

  final target = find.text(label);
  expect(target, findsOneWidget);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _clearActiveSearch(WidgetTester tester) async {
  // Prefer empty enterText over the Clear icon — after segment swaps the
  // suffix IconButton can sit outside the hit-testable search field bounds in
  // widget tests. Empty input still commits immediately on the active tab.
  await tester.enterText(_searchField, '');
  await tester.pump();
  expect(
    tester.widget<TextField>(_searchField).controller?.text ?? 'x',
    isEmpty,
  );
}

Future<void> _typeAndSettle(
  WidgetTester tester,
  String query, {
  bool settle = true,
}) async {
  await tester.ensureVisible(_searchField);
  await tester.enterText(_searchField, query);
  await tester.pump();
  if (!settle) return;
  await tester.pump(SearchCommitPolicy.localCollection);
  await tester.pump();
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
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _resetCounters();
  });

  testWidgets('1. Shelf query does not appear in Wishlist', (tester) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'Alpha');
    expect(find.text('Alpha'), findsOneWidget);

    await _openSegment(tester, 'Wishlist');
    expect(find.text('Alpha'), findsNothing);
    expect(find.byType(CollectionWishlistPage), findsOneWidget);
    expect(
      (tester.widget<TextField>(_searchField).controller?.text ?? ''),
      isEmpty,
    );
  });

  testWidgets('2. Wishlist query does not appear in Shelf', (tester) async {
    await _pumpCollectionScreen(tester);
    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull');
    expect(find.text('Skull'), findsOneWidget);

    await _openSegment(tester, 'Shelf');
    expect(find.text('Skull'), findsNothing);
    expect(
      (tester.widget<TextField>(_searchField).controller?.text ?? ''),
      isEmpty,
    );
    expect(CollectionScreen.debugShelfCommittedQuery, isEmpty);
    expect(CollectionScreen.debugWishlistCommittedQuery, 'Skull');
  });

  testWidgets('3. Shelf query restored after switching away and back', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'Alpha');

    await _openSegment(tester, 'Wishlist');
    expect(find.text('Alpha'), findsNothing);

    await _openSegment(tester, 'Shelf');
    expect(find.text('Alpha'), findsOneWidget);
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');
  });

  testWidgets('4. Wishlist query restored after switching away and back', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester);
    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull');

    await _openSegment(tester, 'Shelf');
    expect(find.text('Skull'), findsNothing);

    await _openSegment(tester, 'Wishlist');
    expect(find.text('Skull'), findsOneWidget);
    expect(CollectionScreen.debugWishlistCommittedQuery, 'Skull');
    expect(find.textContaining('Wishlist Skullpanda'), findsOneWidget);
  });

  testWidgets('5. Shelf and Wishlist committed queries remain independent', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'Alpha');
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');

    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull');
    expect(CollectionScreen.debugWishlistCommittedQuery, 'Skull');
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');

    await _openSegment(tester, 'Shelf');
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');
    expect(CollectionScreen.debugWishlistCommittedQuery, 'Skull');
  });

  testWidgets(
    '6. Pending Shelf debounce cannot commit after switching to Wishlist',
    (tester) async {
      await _pumpCollectionScreen(tester);
      _resetCounters();

      await _typeAndSettle(tester, 'Alpha', settle: false);
      expect(CollectionScreen.debugShelfCommittedQueryCount, 0);

      await _openSegment(tester, 'Wishlist');
      await tester.pump(SearchCommitPolicy.localCollection);
      await tester.pump();

      expect(CollectionScreen.debugShelfCommittedQueryCount, 0);
      expect(CollectionScreen.debugShelfCommittedQuery, isEmpty);
      expect(CollectionScreen.debugWishlistCommittedQueryCount, 0);
      expect(find.text('Alpha'), findsNothing);
    },
  );

  testWidgets(
    '7. Pending Wishlist debounce cannot commit after switching to Shelf',
    (tester) async {
      await _pumpCollectionScreen(tester);
      await _openSegment(tester, 'Wishlist');
      _resetCounters();

      await _typeAndSettle(tester, 'Skull', settle: false);
      expect(CollectionScreen.debugWishlistCommittedQueryCount, 0);

      await _openSegment(tester, 'Shelf');
      await tester.pump(SearchCommitPolicy.localCollection);
      await tester.pump();

      expect(CollectionScreen.debugWishlistCommittedQueryCount, 0);
      expect(CollectionScreen.debugWishlistCommittedQuery, isEmpty);
      expect(CollectionScreen.debugShelfCommittedQueryCount, 0);
      expect(find.text('Skull'), findsNothing);
    },
  );

  testWidgets('8. Clear on Shelf does not clear Wishlist', (tester) async {
    await _pumpCollectionScreen(tester);
    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull');

    await _openSegment(tester, 'Shelf');
    await _typeAndSettle(tester, 'Alpha');
    await _clearActiveSearch(tester);

    expect(CollectionScreen.debugShelfCommittedQuery, isEmpty);
    expect(find.text('Alpha'), findsNothing);
    expect(CollectionScreen.debugWishlistCommittedQuery, 'Skull');

    await _openSegment(tester, 'Wishlist');
    expect(find.text('Skull'), findsOneWidget);
  });

  testWidgets('9. Clear on Wishlist does not clear Shelf', (tester) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'Alpha');

    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull');
    await _clearActiveSearch(tester);

    expect(CollectionScreen.debugWishlistCommittedQuery, isEmpty);
    expect(find.text('Skull'), findsNothing);
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');

    await _openSegment(tester, 'Shelf');
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('10. Filters and sort remain tab-local', (tester) async {
    await _pumpCollectionScreen(tester);

    await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Collection Attributes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filters_sheet_has_duplicates')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Filters · 1'), findsOneWidget);

    await _openSegment(tester, 'Wishlist');
    expect(find.byType(CollectionWishlistPage), findsOneWidget);
    expect(find.textContaining('Wishlist Skullpanda'), findsOneWidget);
    expect(find.textContaining('Wishlist Hirono'), findsOneWidget);

    await _openSegment(tester, 'Shelf');
    // Shelf filters preserved independently of Wishlist.
    expect(find.text('Filters · 1'), findsOneWidget);
  });

  testWidgets('11. Empty/no-results states do not bleed across tabs', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'zzzz-no-match');
    expect(find.text('No series match your search.'), findsOneWidget);

    await _openSegment(tester, 'Wishlist');
    expect(find.text('No series match your search.'), findsNothing);
    expect(find.text('No Wishlist results found.'), findsNothing);
    expect(find.textContaining('Wishlist Skullpanda'), findsOneWidget);

    await _typeAndSettle(tester, 'zzzz-wishlist-miss');
    expect(find.text('No Wishlist results found.'), findsOneWidget);
    expect(find.text('No series match your search.'), findsNothing);

    await _openSegment(tester, 'Shelf');
    expect(find.text('No series match your search.'), findsOneWidget);
    expect(find.text('No Wishlist results found.'), findsNothing);
  });

  testWidgets('12. Insights does not clear either query', (tester) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'Alpha');

    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull');

    await _openSegment(tester, 'Insights');
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');
    expect(CollectionScreen.debugWishlistCommittedQuery, 'Skull');

    await _openSegment(tester, 'Shelf');
    expect(find.text('Alpha'), findsOneWidget);

    await _openSegment(tester, 'Wishlist');
    expect(find.text('Skull'), findsOneWidget);
  });

  testWidgets('13. Both tabs still use 250ms localCollection', (tester) async {
    expect(
      SearchCommitPolicy.localCollection,
      const Duration(milliseconds: 250),
    );

    await _pumpCollectionScreen(tester);
    _resetCounters();
    await _typeAndSettle(tester, 'Alpha', settle: false);
    await tester.pump(const Duration(milliseconds: 249));
    expect(CollectionScreen.debugShelfCommittedQueryCount, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(CollectionScreen.debugShelfCommittedQueryCount, 1);

    await _openSegment(tester, 'Wishlist');
    _resetCounters();
    await _typeAndSettle(tester, 'Skull', settle: false);
    await tester.pump(const Duration(milliseconds: 249));
    expect(CollectionScreen.debugWishlistCommittedQueryCount, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(CollectionScreen.debugWishlistCommittedQueryCount, 1);
  });

  testWidgets('14. Dispose cancels both schedulers', (tester) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'Alpha', settle: false);

    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull', settle: false);

    _resetCounters();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    expect(CollectionScreen.debugShelfCommittedQueryCount, 0);
    expect(CollectionScreen.debugWishlistCommittedQueryCount, 0);
    expect(CollectionScreen.debugCommittedQueryCount, 0);
  });

  testWidgets('15. Shelf cache uses only Shelf committed query', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester);
    await _typeAndSettle(tester, 'Alpha');
    final shelfSearches = ShelfBrowseSearchMatchCache.debugSearchExecutionCount;
    expect(shelfSearches, greaterThan(0));
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');

    await _openSegment(tester, 'Wishlist');
    await _typeAndSettle(tester, 'Skull');
    expect(
      ShelfBrowseSearchMatchCache.debugSearchExecutionCount,
      shelfSearches,
    );
    expect(CollectionScreen.debugWishlistCommittedQuery, 'Skull');
    expect(CollectionScreen.debugShelfCommittedQuery, 'Alpha');
  });

  testWidgets('16. Inactive tab does not run expensive Shelf filtering', (
    tester,
  ) async {
    await _pumpCollectionScreen(tester);
    await _openSegment(tester, 'Wishlist');
    _resetCounters();

    await _typeAndSettle(tester, 'Skull');
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
    expect(CollectionScreen.debugPartitionCount, 0);
    expect(CollectionScreen.debugSortCount, 0);
    expect(CollectionWishlistPage.debugFilterCount, greaterThan(0));
  });
}
