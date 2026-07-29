import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filter_matching.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_shelf_logic_fixtures.dart';

List<String> _ids(Iterable<ShelfSeries> rows) =>
    rows.map((s) => s.id).toList(growable: false);

List<ShelfSeries> _filter(
  CollectionShelfLogicMatrix m,
  CollectionShelfFilters filters,
) {
  return applyCollectionShelfFilters(
    m.shelfSeries,
    m.figureStates,
    filters,
    catalog: m.catalogLookup,
  );
}

CollectionShelfFilterPreview _preview(
  CollectionShelfLogicMatrix m,
  CollectionShelfFilters filters, {
  String searchQuery = '',
}) {
  return previewCollectionShelfFilterResults(
    shelfSeries: m.shelfSeries,
    figureStates: m.figureStates,
    filters: filters,
    searchQuery: searchQuery,
    catalog: m.catalogLookup,
    catalogBundle: m.catalogBundle,
  );
}

List<ShelfSeries> _pipeline(
  CollectionShelfLogicMatrix m, {
  CollectionShelfFilters filters = CollectionShelfFilters.empty,
  CollectionShelfSort sort = CollectionShelfSort.recentlyAdded,
  String searchQuery = '',
}) {
  final preview = _preview(m, filters, searchQuery: searchQuery);
  return sortShelfSeriesForDisplay(
    preview.series,
    sort,
    m.figureStates,
    catalog: m.catalogBundle,
  );
}

void main() {
  late CollectionShelfLogicMatrix m;

  setUp(() {
    m = CollectionShelfLogicFixtures.build();
  });

  group('CollectionShelfFilters model (draft / applied)', () {
    test('opening sheet semantics: copy applied into independent draft', () {
      const applied = CollectionShelfFilters(
        hasDuplicates: true,
        brandIds: {'popmart'},
      );
      var draft = applied;
      draft = draft.copyWith(secretOwned: true);
      expect(applied.secretOwned, isFalse);
      expect(draft.secretOwned, isTrue);
      expect(draft.hasDuplicates, isTrue);
      expect(draft.brandIds, {'popmart'});
    });

    test('Clear all on draft does not mutate prior applied until commit', () {
      const applied = CollectionShelfFilters(
        hasWishlistItems: true,
        ipIds: {'hirono'},
      );
      var draft = applied;
      draft = draft.cleared();
      expect(draft, CollectionShelfFilters.empty);
      expect(applied.hasWishlistItems, isTrue);
      expect(applied.ipIds, {'hirono'});
    });

    test('applying a cleared draft restores the unfiltered Series set', () {
      final m = CollectionShelfLogicFixtures.build();
      const applied = CollectionShelfFilters(hasDuplicates: true);
      expect(_ids(_filter(m, applied)), ['bravo_dups']);
      final committed = applied.cleared();
      expect(_ids(_filter(m, committed)), m.allIds);
    });

    test('preview count is Series count, not figure count', () {
      final m = CollectionShelfLogicFixtures.build();
      final preview = _preview(
        m,
        const CollectionShelfFilters(secretMissing: true),
      );
      expect(preview.count, 2);
      expect(preview.count, preview.series.length);
      final figureTotal = preview.series.fold<int>(
        0,
        (n, s) => n + s.figureCount,
      );
      expect(preview.count, isNot(figureTotal));
    });

    test('activeCount counts each Brand, IP, and attribute once', () {
      const filters = CollectionShelfFilters(
        progress: CollectionShelfProgressFilter.inProgress,
        hasDuplicates: true,
        hasWishlistItems: true,
        secretOwned: true,
        secretMissing: true,
        customSeries: true,
        brandIds: {'popmart', 'toptoy'},
        ipIds: {'hirono', 'molly', 'skullpanda'},
      );
      expect(filters.activeCount, 1 + 5 + 2 + 3);
      expect(filters.hasActive, isTrue);
    });

    test('Time filters are absent from the filter model', () {
      expect(
        CollectionShelfFilters.empty.toString().toLowerCase(),
        isNot(contains('recently')),
      );
      // No Time fields on the model — only Progress / attributes / Brand / IP.
      const f = CollectionShelfFilters(hasDuplicates: true);
      expect(f.activeCount, 1);
      expect(
        CollectionShelfSort.values.map((s) => s.name),
        containsAll(['recentlyAdded', 'recentlyReleased']),
      );
    });
  });

  group('Filtering predicates', () {
    test('1. no filters returns all eligible Collection Series', () {
      expect(_ids(_filter(m, CollectionShelfFilters.empty)), m.allIds);
      expect(
        identical(_filter(m, CollectionShelfFilters.empty), m.shelfSeries),
        isTrue,
      );
    });

    test('2/3. Has Duplicates matches qty>1 only; qty==1 excluded', () {
      expect(
        _ids(_filter(m, const CollectionShelfFilters(hasDuplicates: true))),
        ['bravo_dups'],
      );
      expect(
        _ids(_filter(m, const CollectionShelfFilters(hasDuplicates: true))),
        isNot(contains('alpha_mixed')),
      );
    });

    test('4. duplicates do not inflate completion ratios', () {
      final dups = m.byId('bravo_dups');
      final resolution = resolveSeriesCompletion(dups, m.figureStates);
      // 2 unique owned figures / 2 slots — quantity 3 on b_r0 does not add.
      expect(resolution.regularOwnedCount, 2);
      expect(resolution.progressRatio, 1.0);
      expect(m.figureStates['b_r0']!.ownedQuantity, 3);
    });

    test('5. Has Wishlist Items matches correctly', () {
      expect(
        _ids(_filter(m, const CollectionShelfFilters(hasWishlistItems: true))),
        ['charlie_wish'],
      );
      expect(
        _ids(_filter(m, const CollectionShelfFilters(hasWishlistItems: true))),
        isNot(contains('bravo_dups')),
      );
    });

    test('6/7. Secret Owned needs secret metadata; quantity irrelevant', () {
      expect(
        _ids(_filter(m, const CollectionShelfFilters(secretOwned: true))),
        containsAll(['delta_secret_owned', 'echo_secret_missing']),
      );
      // ownedQuantity > 1 on a Secret still matches Secret Owned (boolean).
      final highQty = CollectionShelfLogicFixtures.series(
        id: 'secret_qty',
        name: 'Secret Qty',
        catalogTemplateId: 'cat_delta',
        brand: 'TOP TOY',
        taxonomyBrandId: 'toptoy',
        ipName: 'Skullpanda',
        taxonomyIpId: 'skullpanda',
        figures: [
          CollectionShelfLogicFixtures.fig(
            'sq_s0',
            'secret_qty',
            secret: true,
            catalogFigureTemplateId: 'cat_delta_s0',
          ),
        ],
      );
      expect(
        applyCollectionShelfFilters(
          [highQty],
          {'sq_s0': CollectionShelfLogicFixtures.owned('sq_s0', qty: 5)},
          const CollectionShelfFilters(secretOwned: true),
          catalog: m.catalogLookup,
        ).map((s) => s.id),
        ['secret_qty'],
      );
    });

    test('8/9. Secret Missing requires unowned secret; all owned excluded', () {
      expect(
        _ids(_filter(m, const CollectionShelfFilters(secretMissing: true))),
        ['echo_secret_missing', 'golf_complete'],
      );
      expect(
        _ids(_filter(m, const CollectionShelfFilters(secretMissing: true))),
        isNot(contains('delta_secret_owned')),
      );
    });

    test('10. series with no Secret figures match neither Secret filter', () {
      final owned = _ids(
        _filter(m, const CollectionShelfFilters(secretOwned: true)),
      );
      final missing = _ids(
        _filter(m, const CollectionShelfFilters(secretMissing: true)),
      );
      expect(owned, isNot(contains('alpha_mixed')));
      expect(missing, isNot(contains('alpha_mixed')));
      expect(owned, isNot(contains('india_name_secret')));
      expect(missing, isNot(contains('india_name_secret')));
    });

    test('11. Secret status is not inferred from figure names', () {
      expect(
        _ids(_filter(m, const CollectionShelfFilters(secretOwned: true))),
        isNot(contains('india_name_secret')),
      );
      final fig = m.byId('india_name_secret').figures.single;
      expect(fig.name.toLowerCase(), contains('secret'));
      expect(fig.isSecret, isFalse);
    });

    test('12. Custom Series uses isCustomLocal marker', () {
      expect(m.byId('foxtrot_custom').isCustomLocal, isTrue);
      expect(
        _ids(_filter(m, const CollectionShelfFilters(customSeries: true))),
        ['foxtrot_custom'],
      );
    });

    test('13/14. Brand filtering; multiple Brands use OR', () {
      expect(
        _ids(_filter(m, CollectionShelfFilters(brandIds: {'toptoy'}))).toSet(),
        {'charlie_wish', 'delta_secret_owned'},
      );
      expect(
        _ids(
          _filter(m, CollectionShelfFilters(brandIds: {'toptoy', 'rolife'})),
        ).toSet(),
        {'charlie_wish', 'delta_secret_owned', 'kilo_many'},
      );
    });

    test('15/16. IP filtering; multiple IPs use OR', () {
      expect(_ids(_filter(m, CollectionShelfFilters(ipIds: {'molly'}))), [
        'kilo_many',
      ]);
      expect(
        _ids(
          _filter(m, CollectionShelfFilters(ipIds: {'molly', 'skullpanda'})),
        ).toSet(),
        {'charlie_wish', 'delta_secret_owned', 'kilo_many'},
      );
    });

    test('17. missing Brand/IP values do not create false matches', () {
      expect(
        _ids(_filter(m, CollectionShelfFilters(brandIds: {'popmart'}))),
        isNot(contains('hotel_no_meta')),
      );
      expect(
        _ids(_filter(m, CollectionShelfFilters(ipIds: {'hirono'}))),
        isNot(contains('hotel_no_meta')),
      );
    });

    test('18. multiple Collection Attributes use AND', () {
      expect(
        _ids(
          _filter(
            m,
            const CollectionShelfFilters(
              hasDuplicates: true,
              hasWishlistItems: true,
            ),
          ),
        ),
        isEmpty,
      );
      expect(
        _ids(
          _filter(
            m,
            const CollectionShelfFilters(
              secretOwned: true,
              secretMissing: true,
            ),
          ),
        ),
        ['echo_secret_missing'],
      );
    });

    test('19. Brand + IP + attributes combine using AND', () {
      expect(
        _ids(
          _filter(
            m,
            CollectionShelfFilters(
              brandIds: {'toptoy'},
              ipIds: {'skullpanda'},
              hasWishlistItems: true,
            ),
          ),
        ),
        ['charlie_wish'],
      );
      expect(
        _ids(
          _filter(
            m,
            CollectionShelfFilters(
              brandIds: {'toptoy'},
              ipIds: {'hirono'},
              hasWishlistItems: true,
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('20/21. search AND filters; matching is case-insensitive', () {
      final previewLower = _preview(
        m,
        CollectionShelfFilters(brandIds: {'popmart'}),
        searchQuery: 'bravo',
      );
      final previewUpper = _preview(
        m,
        CollectionShelfFilters(brandIds: {'popmart'}),
        searchQuery: 'BRAVO',
      );
      expect(_ids(previewLower.series), ['bravo_dups']);
      expect(_ids(previewUpper.series), ['bravo_dups']);
      expect(
        _ids(
          _preview(
            m,
            CollectionShelfFilters(brandIds: {'toptoy'}),
            searchQuery: 'bravo',
          ).series,
        ),
        isEmpty,
      );
    });

    test('22. clearing filters restores the complete eligible dataset', () {
      final cleared = _filter(
        m,
        const CollectionShelfFilters(hasDuplicates: true).cleared(),
      );
      expect(_ids(cleared), m.allIds);
    });

    test('23/24. activeCount and Time absence (model-level)', () {
      expect(
        const CollectionShelfFilters(
          hasDuplicates: true,
          brandIds: {'a', 'b'},
          ipIds: {'x'},
        ).activeCount,
        4,
      );
      expect(
        CollectionShelfFilters.empty.runtimeType.toString(),
        isNot(contains('Time')),
      );
    });
  });

  group('Sorting', () {
    test('Recently Added preserves reliable shelf encounter order', () {
      // Product definition: preserve shelf / bucket traversal — not wall-clock.
      final shuffled = [
        m.byId('kilo_many'),
        m.byId('alpha_mixed'),
        m.byId('bravo_dups'),
      ];
      final sorted = sortShelfSeriesForDisplay(
        shuffled,
        CollectionShelfSort.recentlyAdded,
        m.figureStates,
      );
      expect(_ids(sorted), ['kilo_many', 'alpha_mixed', 'bravo_dups']);
      expect(identical(sorted, shuffled), isTrue);
    });

    test(
      'Recently Released: newest U.S. date first; missing/malformed last',
      () {
        final subset = [
          m.byId('echo_secret_missing'), // 2022-12-01
          m.byId('kilo_many'), // 2026-07-01
          m.byId('hotel_no_meta'), // malformed
          m.byId('india_name_secret'), // missing
          m.byId('bravo_dups'), // 2025-06-01
        ];
        final sorted = sortShelfSeriesForDisplay(
          subset,
          CollectionShelfSort.recentlyReleased,
          m.figureStates,
          catalog: m.catalogBundle,
        );
        expect(_ids(sorted), [
          'kilo_many',
          'bravo_dups',
          'echo_secret_missing',
          'hotel_no_meta',
          'india_name_secret',
        ]);
      },
    );

    test('Recently Released equal dates use name then id tie-breaker', () {
      final sorted = sortShelfSeriesForDisplay(
        [m.byId('lima_alpha_case'), m.byId('alpha_mixed')],
        CollectionShelfSort.recentlyReleased,
        m.figureStates,
        catalog: m.catalogBundle,
      );
      // Same release date 2024-01-15 → "Alpha Series" then "alpha Series"
      // case-insensitive equal names → id: alpha_mixed < lima_alpha_case
      expect(_ids(sorted), ['alpha_mixed', 'lima_alpha_case']);
    });

    test(
      'Recently Released uses parseCatalogReleaseDate (no crash on bad)',
      () {
        expect(parseCatalogReleaseDate('not-a-date'), isNull);
        expect(parseCatalogReleaseDate(''), isNull);
        expect(parseCatalogReleaseDate(null), isNull);
        expect(parseCatalogReleaseDate('2026-07-01'), DateTime(2026, 7, 1));
      },
    );

    test('Alphabetical is case-insensitive with stable secondary key', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          m.byId('lima_alpha_case'), // Alpha Series
          m.byId('alpha_mixed'), // alpha Series
          m.byId('bravo_dups'),
        ],
        CollectionShelfSort.alphabetical,
        m.figureStates,
      );
      expect(_ids(sorted), ['alpha_mixed', 'lima_alpha_case', 'bravo_dups']);
    });

    test('Figure Count uses total series.figures length, descending', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          m.byId('alpha_mixed'), // 2
          m.byId('kilo_many'), // 6
          m.byId('juliet_low'), // 4
        ],
        CollectionShelfSort.figureCount,
        m.figureStates,
      );
      expect(_ids(sorted), ['kilo_many', 'juliet_low', 'alpha_mixed']);
    });

    test('Figure Count equal counts tie-break by name then id', () {
      final a = CollectionShelfLogicFixtures.series(
        id: 'tie_b',
        name: 'SameCount',
        figures: [
          CollectionShelfLogicFixtures.fig('tb0', 'tie_b'),
          CollectionShelfLogicFixtures.fig('tb1', 'tie_b'),
        ],
      );
      final b = CollectionShelfLogicFixtures.series(
        id: 'tie_a',
        name: 'SameCount',
        figures: [
          CollectionShelfLogicFixtures.fig('ta0', 'tie_a'),
          CollectionShelfLogicFixtures.fig('ta1', 'tie_a'),
        ],
      );
      final sorted = sortShelfSeriesForDisplay(
        [a, b],
        CollectionShelfSort.figureCount,
        const {},
      );
      expect(_ids(sorted), ['tie_a', 'tie_b']);
    });

    test('Completion uses unique owned figures; duplicates do not inflate', () {
      final dups = m.byId('bravo_dups');
      final low = m.byId('juliet_low');
      final sorted = sortShelfSeriesForDisplay(
        [low, dups],
        CollectionShelfSort.completion,
        m.figureStates,
      );
      // bravo 2/2 complete > juliet 1/4 in progress
      expect(_ids(sorted), ['bravo_dups', 'juliet_low']);
      expect(resolveSeriesCompletion(dups, m.figureStates).progressRatio, 1.0);
    });

    test('Completion tiers: Master → Complete → In Progress; no div/0', () {
      final master = m.byId('delta_secret_owned'); // regular+secret owned
      final complete = m.byId('golf_complete'); // regulars done, secret missing
      final inProgress = m.byId('juliet_low');
      final emptyFigs = ShelfSeries(
        id: 'zero_figs',
        name: 'Zero',
        brand: 'X',
        ipName: 'Y',
        figures: const [],
        shelfAccent: CollectionShelfLogicFixtures.accent,
        catalogTemplateId: null,
      );
      final sorted = sortShelfSeriesForDisplay(
        [inProgress, complete, master, emptyFigs],
        CollectionShelfSort.completion,
        m.figureStates,
      );
      expect(_ids(sorted).take(3).toList(), [
        'delta_secret_owned',
        'golf_complete',
        'juliet_low',
      ]);
      expect(resolveSeriesCompletion(emptyFigs, const {}).progressRatio, 0.0);
    });

    test('sort does not mutate the input list for non-recentlyAdded modes', () {
      final input = [m.byId('bravo_dups'), m.byId('alpha_mixed')];
      final before = List<String>.from(_ids(input));
      final sorted = sortShelfSeriesForDisplay(
        input,
        CollectionShelfSort.alphabetical,
        m.figureStates,
      );
      expect(_ids(input), before);
      expect(_ids(sorted), ['alpha_mixed', 'bravo_dups']);
      expect(identical(sorted, input), isFalse);
    });
  });

  group('Combined pipeline', () {
    test('1. search → filter → sort yields expected ordered IDs', () {
      final ordered = _pipeline(
        m,
        filters: CollectionShelfFilters(brandIds: {'popmart'}),
        searchQuery: '',
        sort: CollectionShelfSort.alphabetical,
      );
      expect(_ids(ordered), [
        'alpha_mixed',
        'lima_alpha_case',
        'bravo_dups',
        'echo_secret_missing',
        'golf_complete',
        'india_name_secret',
        'juliet_low',
      ]);
    });

    test(
      '2/3. applying filter preserves sort; changing sort preserves filters',
      () {
        final filteredAlpha = _pipeline(
          m,
          filters: const CollectionShelfFilters(customSeries: true),
          sort: CollectionShelfSort.alphabetical,
        );
        expect(_ids(filteredAlpha), ['foxtrot_custom']);

        final filteredByCount = _pipeline(
          m,
          filters: CollectionShelfFilters(brandIds: {'popmart'}),
          sort: CollectionShelfSort.figureCount,
        );
        expect(
          filteredByCount.every((s) {
            return s.taxonomyBrandId == 'pop_mart' ||
                s.brand.toLowerCase().contains('pop');
          }),
          isTrue,
        );
        expect(filteredByCount.first.figureCount, greaterThanOrEqualTo(2));
      },
    );

    test('4. Brand/IP OR still ANDs with attributes', () {
      expect(
        _ids(
          _pipeline(
            m,
            filters: CollectionShelfFilters(
              brandIds: {'toptoy', 'rolife'},
              hasWishlistItems: true,
            ),
          ),
        ),
        ['charlie_wish'],
      );
    });

    test('5. empty result when no Series satisfies all constraints', () {
      expect(
        _ids(
          _pipeline(
            m,
            filters: const CollectionShelfFilters(
              customSeries: true,
              hasDuplicates: true,
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('6. Grid / Compact Grid / List receive identical ordered IDs', () {
      final ordered = _pipeline(
        m,
        filters: CollectionShelfFilters(brandIds: {'toptoy'}),
        sort: CollectionShelfSort.alphabetical,
      );
      final ids = _ids(ordered);
      for (final _ in CollectionShelfLayout.values) {
        expect(_ids(ordered), ids);
      }
      expect(CollectionShelfLayout.values, hasLength(3));
    });

    test('7. repeated execution returns identical ordering', () {
      List<String> run() => _ids(
        _pipeline(
          m,
          filters: CollectionShelfFilters(brandIds: {'popmart'}),
          sort: CollectionShelfSort.recentlyReleased,
        ),
      );
      expect(run(), run());
      expect(run(), run());
    });

    test('8. filtering does not mutate input collections', () {
      final beforeIds = List<String>.from(m.allIds);
      final beforeStates = Map<String, TrackedFigure>.from(m.figureStates);
      _filter(m, const CollectionShelfFilters(hasDuplicates: true));
      _pipeline(
        m,
        filters: CollectionShelfFilters(brandIds: {'popmart'}),
        sort: CollectionShelfSort.alphabetical,
      );
      expect(m.allIds, beforeIds);
      expect(m.figureStates.keys.toSet(), beforeStates.keys.toSet());
    });

    test('9/10. preview count ignores sort; equals applied filter count', () {
      const filters = CollectionShelfFilters(secretMissing: true);
      final preview = _preview(m, filters);
      final applied = _filter(m, filters);
      final sorted = sortShelfSeriesForDisplay(
        applied,
        CollectionShelfSort.alphabetical,
        m.figureStates,
      );
      expect(preview.count, applied.length);
      expect(preview.count, sorted.length);
      expect(_ids(preview.series).toSet(), _ids(applied).toSet());
      expect(preview.count, isNot(0));
    });
  });

  group('Catalog-backed Secret enrichment', () {
    test('shelf isSecret false still matches via catalog template id', () {
      final legacy = CollectionShelfLogicFixtures.series(
        id: 'legacy_secret',
        name: 'Legacy',
        catalogTemplateId: 'cat_legacy',
        figures: [
          CollectionShelfLogicFixtures.fig(
            'leg_r',
            'legacy_secret',
            secret: false,
            catalogFigureTemplateId: 'cat_legacy_s',
          ),
        ],
      );
      final lookup = CatalogBundleLookup.fromBundle(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [
            CollectionShelfLogicFixtures.catSeries('cat_legacy', '2024-01-01'),
          ],
          figures: [
            CollectionShelfLogicFixtures.catFig(
              'cat_legacy_s',
              'cat_legacy',
              secret: true,
            ),
          ],
        ),
      );
      expect(legacy.figures.single.isSecret, isFalse);
      expect(
        shelfFigureIsSecretForFilter(legacy.figures.single, lookup),
        isTrue,
      );
      expect(
        applyCollectionShelfFilters(
          [legacy],
          {'leg_r': CollectionShelfLogicFixtures.owned('leg_r')},
          const CollectionShelfFilters(secretOwned: true),
          catalog: lookup,
        ).map((s) => s.id),
        ['legacy_secret'],
      );
    });
  });
}
