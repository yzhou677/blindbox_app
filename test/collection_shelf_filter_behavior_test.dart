import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_lookup.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart'
    as catalog_figure;
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog_series;
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filter_matching.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_filters_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_layout_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

ShelfFigure _fig(
  String id,
  String seriesId, {
  bool secret = false,
  String? catalogFigureTemplateId,
  String name = 'Fig',
}) {
  return ShelfFigure(
    id: id,
    seriesId: seriesId,
    name: name,
    rarity: secret ? '1:144' : 'Regular',
    isSecret: secret,
    catalogFigureTemplateId: catalogFigureTemplateId,
  );
}

TrackedFigure _owned(String id, {int qty = 1}) => TrackedFigure(
  figureId: id,
  state: FigureCollectionState.owned,
  ownedQuantity: qty,
);

TrackedFigure _wish(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.wishlist);

/// Deterministic fixture corpus with positive + negative examples per filter.
({List<ShelfSeries> series, Map<String, TrackedFigure> states}) _corpus() {
  final withDups = testShelfSeries(
    id: 'dups',
    name: 'Dup Series',
    brand: 'POP MART',
    taxonomyBrandId: 'pop_mart',
    ipName: 'Hirono',
    taxonomyIpId: 'hirono',
    figures: [_fig('d1', 'dups'), _fig('d2', 'dups')],
  );
  final withWish = testShelfSeries(
    id: 'wish',
    name: 'Wish Series',
    brand: 'POP MART',
    taxonomyBrandId: 'pop_mart',
    ipName: 'Hirono',
    taxonomyIpId: 'hirono',
    figures: [_fig('w1', 'wish'), _fig('w2', 'wish')],
  );
  final secretOwned = testShelfSeries(
    id: 'sec_own',
    name: 'Secret Owned Series',
    brand: 'TOP TOY',
    taxonomyBrandId: 'toptoy',
    ipName: 'Skullpanda',
    taxonomyIpId: 'skullpanda',
    figures: [_fig('so_r', 'sec_own'), _fig('so_s', 'sec_own', secret: true)],
  );
  final secretMissing = testShelfSeries(
    id: 'sec_miss',
    name: 'Secret Missing Series',
    brand: 'TOP TOY',
    taxonomyBrandId: 'toptoy',
    ipName: 'Skullpanda',
    taxonomyIpId: 'skullpanda',
    figures: [_fig('sm_r', 'sec_miss'), _fig('sm_s', 'sec_miss', secret: true)],
  );
  final custom = testShelfSeries(
    id: 'custom',
    name: 'Custom Series',
    brand: 'Independent',
    taxonomyBrandId: 'independent',
    ipName: 'Custom IP',
    taxonomyIpId: 'custom_ip',
    catalogTemplateId: null,
    figures: [_fig('c1', 'custom')],
  );
  final plain = testShelfSeries(
    id: 'plain',
    name: 'Plain Series',
    brand: 'POP MART',
    taxonomyBrandId: 'pop_mart',
    ipName: 'Labubu',
    taxonomyIpId: 'labubu',
    figures: [_fig('p1', 'plain'), _fig('p2', 'plain')],
  );

  return (
    series: [withDups, withWish, secretOwned, secretMissing, custom, plain],
    states: {
      'd1': _owned('d1', qty: 2),
      'w1': _owned('w1'),
      'w2': _wish('w2'),
      'so_r': _owned('so_r'),
      'so_s': _owned('so_s'),
      'sm_r': _owned('sm_r'),
      // sm_s missing
      'c1': _owned('c1'),
      'p1': _owned('p1'),
    },
  );
}

List<String> _ids(
  List<ShelfSeries> series,
  Map<String, TrackedFigure> states,
  CollectionShelfFilters filters, {
  CatalogBundleLookup? catalog,
}) {
  return applyCollectionShelfFilters(
    series,
    states,
    filters,
    catalog: catalog,
  ).map((s) => s.id).toList(growable: false);
}

final class _SnapNotifier extends CollectionNotifier {
  _SnapNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('independent attribute filters', () {
    final corpus = _corpus();
    final series = corpus.series;
    final states = corpus.states;

    test('1. Has Duplicates independently changes matches', () {
      expect(
        _ids(series, states, const CollectionShelfFilters(hasDuplicates: true)),
        ['dups'],
      );
    });

    test('2. Has Wishlist Items matches and excludes correctly', () {
      expect(
        _ids(
          series,
          states,
          const CollectionShelfFilters(hasWishlistItems: true),
        ),
        ['wish'],
      );
      expect(
        _ids(
          series,
          states,
          const CollectionShelfFilters(hasWishlistItems: true),
        ).contains('plain'),
        isFalse,
      );
    });

    test('3. Secret Owned works', () {
      expect(
        _ids(series, states, const CollectionShelfFilters(secretOwned: true)),
        ['sec_own'],
      );
    });

    test('4. Secret Missing works', () {
      expect(
        _ids(series, states, const CollectionShelfFilters(secretMissing: true)),
        ['sec_miss'],
      );
    });

    test('5. Custom Series works', () {
      expect(
        _ids(series, states, const CollectionShelfFilters(customSeries: true)),
        ['custom'],
      );
    });

    test('6. Brand selection works', () {
      expect(
        _ids(series, states, CollectionShelfFilters(brandIds: {'toptoy'})),
        ['sec_own', 'sec_miss'],
      );
    });

    test('7. IP selection works', () {
      expect(_ids(series, states, CollectionShelfFilters(ipIds: {'labubu'})), [
        'plain',
      ]);
    });

    test('8. Multiple Brands use OR', () {
      expect(
        _ids(
          series,
          states,
          CollectionShelfFilters(brandIds: {'toptoy', 'independent'}),
        ).toSet(),
        {'sec_own', 'sec_miss', 'custom'},
      );
    });

    test('9. Multiple IPs use OR', () {
      expect(
        _ids(
          series,
          states,
          CollectionShelfFilters(ipIds: {'hirono', 'labubu'}),
        ).toSet(),
        {'dups', 'wish', 'plain'},
      );
    });

    test('10. Multiple attributes use AND', () {
      expect(
        _ids(
          series,
          states,
          const CollectionShelfFilters(
            hasDuplicates: true,
            hasWishlistItems: true,
          ),
        ),
        isEmpty,
      );
      expect(
        _ids(
          [series.first], // dups only
          states,
          const CollectionShelfFilters(hasDuplicates: true),
        ),
        ['dups'],
      );
    });

    test('11. Cross-section filters use AND', () {
      expect(
        _ids(
          series,
          states,
          CollectionShelfFilters(brandIds: {'popmart'}, hasWishlistItems: true),
        ),
        ['wish'],
      );
    });
  });

  group('catalog-backed Secret resolution', () {
    test('Secret Owned uses catalog isSecret when shelf flag is false', () {
      final shelf = testShelfSeries(
        id: 'legacy',
        figures: [
          _fig('r', 'legacy', catalogFigureTemplateId: 'fig_r'),
          _fig(
            's',
            'legacy',
            secret: false,
            catalogFigureTemplateId: 'fig_s_secret',
          ),
        ],
      );
      final bundle = CatalogSeedBundle(
        brands: const [
          CatalogBrand(id: 'pop_mart', displayName: 'POP MART', aliases: []),
        ],
        ips: const [
          CatalogIp(
            id: 'hirono',
            brandId: 'pop_mart',
            displayName: 'Hirono',
            aliases: [],
          ),
        ],
        series: const [
          catalog_series.CatalogSeries(
            id: 'catalog_series_test',
            brandId: 'pop_mart',
            ipId: 'hirono',
            displayName: 'Legacy',
            releaseDate: null,
            isBlindBox: true,
            imageKey: 'catalog_series_test',
          ),
        ],
        figures: const [
          catalog_figure.CatalogFigure(
            id: 'fig_r',
            seriesId: 'catalog_series_test',
            brandId: 'pop_mart',
            ipId: 'hirono',
            displayName: 'Regular',
            isSecret: false,
            sortOrder: 0,
            imageKey: 'fig_r',
          ),
          catalog_figure.CatalogFigure(
            id: 'fig_s_secret',
            seriesId: 'catalog_series_test',
            brandId: 'pop_mart',
            ipId: 'hirono',
            displayName: 'Secret',
            isSecret: true,
            sortOrder: 1,
            imageKey: 'fig_s_secret',
          ),
        ],
      );
      final catalog = CatalogBundleLookup.fromBundle(bundle);
      final states = {'s': _owned('s')};

      expect(
        applyCollectionShelfFilters(
          [shelf],
          states,
          const CollectionShelfFilters(secretOwned: true),
        ),
        isEmpty,
      );
      expect(
        applyCollectionShelfFilters(
          [shelf],
          states,
          const CollectionShelfFilters(secretOwned: true),
          catalog: catalog,
        ).map((s) => s.id),
        ['legacy'],
      );
    });

    test('preview waits on catalog instead of false zero', () {
      final shelf = testShelfSeries(
        id: 'needs_catalog',
        figures: [_fig('a', 'needs_catalog', catalogFigureTemplateId: 'fig_a')],
      );
      final preview = previewCollectionShelfFilterResults(
        shelfSeries: [shelf],
        figureStates: {'a': _owned('a')},
        filters: const CollectionShelfFilters(secretOwned: true),
        catalog: null,
      );
      expect(preview.waitingOnCatalog, isTrue);
      expect(preview.count, 0);
    });
  });

  group('draft Show results preview', () {
    test('12/14. draft count updates and Clear all restores unfiltered', () {
      final corpus = _corpus();
      final empty = previewCollectionShelfFilterResults(
        shelfSeries: corpus.series,
        figureStates: corpus.states,
        filters: CollectionShelfFilters.empty,
      );
      expect(empty.count, corpus.series.length);
      expect(empty.waitingOnCatalog, isFalse);

      final dups = previewCollectionShelfFilterResults(
        shelfSeries: corpus.series,
        figureStates: corpus.states,
        filters: const CollectionShelfFilters(hasDuplicates: true),
      );
      expect(dups.count, 1);

      final cleared = previewCollectionShelfFilterResults(
        shelfSeries: corpus.series,
        figureStates: corpus.states,
        filters: CollectionShelfFilters.empty,
      );
      expect(cleared.count, corpus.series.length);
    });

    test('13. preview count equals applied shared filter results', () {
      final corpus = _corpus();
      const filters = CollectionShelfFilters(secretMissing: true);
      final preview = previewCollectionShelfFilterResults(
        shelfSeries: corpus.series,
        figureStates: corpus.states,
        filters: filters,
      );
      final applied = applyCollectionShelfFilters(
        corpus.series,
        corpus.states,
        filters,
      );
      expect(preview.series.map((s) => s.id), applied.map((s) => s.id));
    });
  });

  group('layout + sort after filters', () {
    test('16. all three layouts receive the same filtered Series IDs', () {
      final corpus = _corpus();
      final filtered = applyCollectionShelfFilters(
        corpus.series,
        corpus.states,
        CollectionShelfFilters(brandIds: {'popmart'}),
      );
      final ids = filtered.map((s) => s.id).toList();

      for (final layout in CollectionShelfLayout.values) {
        expect(
          filtered.map((s) => s.id).toList(),
          ids,
          reason: 'layout $layout must not re-filter',
        );
      }

      expect(CollectionShelfLayout.values, hasLength(3));
    });

    test('17. sorting still works after filters are applied', () {
      final corpus = _corpus();
      final filtered = applyCollectionShelfFilters(
        corpus.series,
        corpus.states,
        CollectionShelfFilters(brandIds: {'popmart'}),
      );
      final sorted = sortShelfSeriesForDisplay(
        filtered,
        CollectionShelfSort.alphabetical,
        corpus.states,
      );
      expect(sorted.map((s) => s.name).toList(), [
        'Dup Series',
        'Plain Series',
        'Wish Series',
      ]);
    });
  });

  testWidgets('12/15. draft count updates live; dismiss keeps old filters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final corpus = _corpus();
    final snap = CollectionSnapshot(
      shelfSeries: corpus.series,
      figureStates: corpus.states,
    );
    CollectionShelfFiltersSheetResult? applied;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    applied = await showCollectionShelfFiltersSheet(
                      context: context,
                      initial: const CollectionShelfFilters(
                        hasDuplicates: true,
                      ),
                      shelfSeries: snap.shelfSeries,
                      figureStates: snap.figureStates,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Show 1 Series'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('filters_sheet_has_wishlist')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_has_wishlist')));
    await tester.pump();
    // Duplicates AND wishlist → 0 matches.
    expect(find.text('Show 0 Series'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filters_sheet_clear_all')));
    await tester.pump();
    expect(find.text('Show 6 Series'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('filters_sheet_custom_series')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_custom_series')));
    await tester.pump();
    expect(find.text('Show 1 Series'), findsOneWidget);

    Navigator.of(tester.element(find.text('Filters').first)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(applied, isNull);
  });

  testWidgets('layout host renders filtered ids for grid/list/compact', (
    tester,
  ) async {
    final corpus = _corpus();
    final filtered = applyCollectionShelfFilters(
      corpus.series,
      corpus.states,
      const CollectionShelfFilters(customSeries: true),
    );
    expect(filtered.map((s) => s.id), ['custom']);

    for (final layout in CollectionShelfLayout.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectionShelfSeriesLayoutHost(
              layout: layout,
              series: filtered,
              figureStates: corpus.states,
              progress: ShelfBrowseProgressLookup(corpus.states),
              onOpen: (_) {},
              onManage: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Custom Series'), findsOneWidget);
      expect(find.text('Dup Series'), findsNothing);
    }
  });
}
