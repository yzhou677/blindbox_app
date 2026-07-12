import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

CatalogSeedBundle _catalogSearchTestBundle() {
  return CatalogSeedBundle(
    brands: parseCatalogBrandsJson(r'''[
      {"id": "pop_mart", "displayName": "POP MART", "aliases": ["POPMART"]}
    ]'''),
    ips: parseCatalogIpsJson(r'''[
      {"id": "the_monsters", "brandId": "pop_mart", "displayName": "THE MONSTERS",
       "aliases": ["Labubu"]},
      {"id": "nommi", "brandId": "pop_mart", "displayName": "Nommi", "aliases": []}
    ]'''),
    series: parseCatalogSeriesJson(r'''[
      {"id": "macaron", "brandId": "pop_mart", "ipId": "the_monsters",
       "displayName": "Exciting Macaron", "releaseDate": "2023-10-27", "isBlindBox": true,
       "thumbnailAsset": "assets/catalog/series/macaron.png"},
      {"id": "nommi_party", "brandId": "pop_mart", "ipId": "nommi",
       "displayName": "Apple Party", "releaseDate": "2024-01-01", "isBlindBox": true,
       "thumbnailAsset": "assets/catalog/series/nommi_party.png"}
    ]'''),
    figures: parseCatalogFiguresJson(r'''[
      {"id": "fig_soy", "seriesId": "macaron", "brandId": "pop_mart",
       "ipId": "the_monsters", "displayName": "Soymilk", "isSecret": false,
       "sortOrder": 1, "thumbnailAsset": "assets/f/soy.png"},
      {"id": "fig_lumi", "seriesId": "macaron", "brandId": "pop_mart",
       "ipId": "the_monsters", "displayName": "Hi Lumi", "isSecret": false,
       "sortOrder": 2, "thumbnailAsset": "assets/f/lumi.png"},
      {"id": "fig_apple", "seriesId": "nommi_party", "brandId": "pop_mart",
       "ipId": "nommi", "displayName": "Apple", "isSecret": false,
       "sortOrder": 1, "thumbnailAsset": "assets/f/apple.png"}
    ]'''),
  );
}

ShelfSeries _series({
  required String id,
  required String name,
  int figureCount = 3,
}) {
  return testShelfSeries(
    id: id,
    name: name,
    figures: [
      for (var i = 0; i < figureCount; i++)
        ShelfFigure(
          id: '${id}_fig_$i',
          seriesId: id,
          name: 'Figure $i',
          rarity: 'Regular',
          isSecret: false,
          catalogFigureTemplateId: '${id}_tpl_$i',
        ),
    ],
  );
}

Map<String, TrackedFigure> _ownedAll(ShelfSeries series) {
  return {
    for (final f in series.figures)
      f.id: TrackedFigure(
        figureId: f.id,
        state: FigureCollectionState.owned,
      ),
  };
}

Map<String, TrackedFigure> _ownedCount(ShelfSeries series, int count) {
  return {
    for (var i = 0; i < count && i < series.figures.length; i++)
      series.figures[i].id: TrackedFigure(
        figureId: series.figures[i].id,
        state: FigureCollectionState.owned,
      ),
  };
}

ShelfSeries _ipSeries({
  required String id,
  required String name,
  required String ipId,
  required String ipLabel,
  int figureCount = 3,
}) {
  return testShelfSeries(
    id: id,
    name: name,
    taxonomyIpId: ipId,
    ipName: ipLabel,
    figures: [
      for (var i = 0; i < figureCount; i++)
        ShelfFigure(
          id: '${id}_fig_$i',
          seriesId: id,
          name: 'Figure $i',
          rarity: 'Regular',
          isSecret: false,
          catalogFigureTemplateId: '${id}_tpl_$i',
        ),
    ],
  );
}

void main() {
  group('filterShelfSeriesBySearch', () {
    test('empty query returns same list reference', () {
      final series = [_series(id: 'a', name: 'Alpha')];
      expect(identical(filterShelfSeriesBySearch(series, ''), series), isTrue);
      expect(identical(filterShelfSeriesBySearch(series, '   '), series), isTrue);
    });

    test('filters case-insensitively by name', () {
      final series = [
        _series(id: 'a', name: 'Labubu Forest'),
        _series(id: 'b', name: 'Crybaby Tears'),
      ];
      final filtered = filterShelfSeriesBySearch(series, 'labubu');
      expect(filtered, hasLength(1));
      expect(filtered.first.id, 'a');
    });

    test('matches catalog IP alias via catalogTemplateId', () {
      final catalog = _catalogSearchTestBundle();
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Exciting Macaron',
          catalogTemplateId: 'macaron',
          ipName: 'THE MONSTERS',
        ),
        testShelfSeries(
          id: 'b',
          name: 'Apple Party',
          catalogTemplateId: 'nommi_party',
          ipName: 'Nommi',
        ),
      ];
      final filtered = filterShelfSeriesBySearch(series, 'labubu', catalog: catalog);
      expect(filtered.map((s) => s.id).toList(), ['a']);
    });

    test('matches all series in IP when query matches IP via catalog', () {
      final catalog = _catalogSearchTestBundle();
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Exciting Macaron',
          catalogTemplateId: 'macaron',
          ipName: 'THE MONSTERS',
        ),
        testShelfSeries(
          id: 'b',
          name: 'Apple Party',
          catalogTemplateId: 'nommi_party',
          ipName: 'Nommi',
        ),
      ];
      final filtered = filterShelfSeriesBySearch(series, 'nommi', catalog: catalog);
      expect(filtered.map((s) => s.id).toList(), ['b']);
    });

    test('matches brand via shelf display fields when catalog absent', () {
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Mystery Set',
          brand: 'POP MART',
          ipName: 'THE MONSTERS',
        ),
      ];
      expect(filterShelfSeriesBySearch(series, 'pop mart'), hasLength(1));
    });

    test('matches IP label on custom rows without catalogTemplateId', () {
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Exciting Macaron',
          ipName: 'Nommi',
          taxonomyIpId: 'nommi',
        ),
      ];
      final filtered = filterShelfSeriesBySearch(series, 'nommi');
      expect(filtered, hasLength(1));
      expect(filtered.first.id, 'a');
    });

    test('matches figure display name via catalogTemplateId', () {
      final catalog = _catalogSearchTestBundle();
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Exciting Macaron',
          catalogTemplateId: 'macaron',
          ipName: 'THE MONSTERS',
        ),
      ];
      expect(
        filterShelfSeriesBySearch(series, 'Hi Lumi', catalog: catalog),
        hasLength(1),
      );
      expect(
        filterShelfSeriesBySearch(series, 'soymilk', catalog: catalog),
        hasLength(1),
      );
    });

    test('matches series display name via catalog search', () {
      final catalog = _catalogSearchTestBundle();
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Shelf label differs',
          catalogTemplateId: 'macaron',
        ),
      ];
      expect(
        filterShelfSeriesBySearch(series, 'exciting macaron', catalog: catalog),
        hasLength(1),
      );
    });

    test('matches brand via catalog search', () {
      final catalog = _catalogSearchTestBundle();
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Shelf label differs',
          catalogTemplateId: 'macaron',
          brand: 'Other label',
        ),
      ];
      expect(
        filterShelfSeriesBySearch(series, 'pop mart', catalog: catalog),
        hasLength(1),
      );
    });

    test('matches drop-import catalogTemplateId for figure queries', () {
      final catalog = _catalogSearchTestBundle();
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Exciting Macaron',
          catalogTemplateId: 'drop-macaron',
          ipName: 'THE MONSTERS',
        ),
      ];
      expect(
        filterShelfSeriesBySearch(series, 'Hi Lumi', catalog: catalog),
        hasLength(1),
      );
    });

    test('matches via shelf figure catalogFigureTemplateId', () {
      final catalog = _catalogSearchTestBundle();
      final series = [
        testShelfSeries(
          id: 'a',
          name: 'Release shelf label',
          catalogTemplateId: 'drop-macaron',
          figures: [
            const ShelfFigure(
              id: 'fig_0',
              seriesId: 'a',
              name: 'Slot label',
              rarity: 'Regular',
              isSecret: false,
              catalogFigureTemplateId: 'fig_lumi',
            ),
          ],
        ),
      ];
      expect(
        filterShelfSeriesBySearch(series, 'Hi Lumi', catalog: catalog),
        hasLength(1),
      );
    });

    test('agrees with CatalogSearchService matchingSeriesIds', () {
      final catalog = _catalogSearchTestBundle();
      final svc = CatalogSearchService(catalog);
      final shelf = [
        testShelfSeries(
          id: 'a',
          name: 'Exciting Macaron',
          catalogTemplateId: 'macaron',
        ),
        testShelfSeries(
          id: 'b',
          name: 'Apple Party',
          catalogTemplateId: 'nommi_party',
        ),
      ];

      for (final query in ['Hi Lumi', 'exciting macaron', 'labubu', 'pop mart']) {
        final expectedIds = svc.matchingSeriesIds(query);
        final filtered = filterShelfSeriesBySearch(shelf, query, catalog: catalog);
        expect(
          filtered.map((s) => s.catalogTemplateId).toSet(),
          expectedIds,
          reason: 'query=$query',
        );
      }
    });
  });

  group('sortShelfSeriesForDisplay', () {
    final series = [
      _series(id: 'c', name: 'Charlie', figureCount: 5),
      _series(id: 'a', name: 'Alpha', figureCount: 2),
      _series(id: 'b', name: 'Bravo', figureCount: 8),
    ];
    const states = <String, TrackedFigure>{};

    test('recentlyAdded preserves input order', () {
      final sorted = sortShelfSeriesForDisplay(
        series,
        CollectionShelfSort.recentlyAdded,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['c', 'a', 'b']);
    });

    test('alphabetical sorts all series by name globally (ignores IP)', () {
      final series = [
        testShelfSeries(
          id: 'n2',
          name: 'Exciting Macaron',
          ipName: 'Nommi',
          taxonomyIpId: 'nommi',
        ),
        testShelfSeries(
          id: 'n1',
          name: 'Apple Party',
          ipName: 'Nommi',
          taxonomyIpId: 'nommi',
        ),
        testShelfSeries(
          id: 'd2',
          name: 'Toy Story',
          ipName: 'Disney',
          taxonomyIpId: 'disney',
        ),
        testShelfSeries(
          id: 'd1',
          name: 'Adventures',
          ipName: 'Disney',
          taxonomyIpId: 'disney',
        ),
      ];
      final sorted = sortShelfSeriesForDisplay(
        series,
        CollectionShelfSort.alphabetical,
        states,
      );
      // Global A→Z by series name — not Disney block then Nommi block.
      expect(sorted.map((s) => s.id).toList(), ['d1', 'n1', 'n2', 'd2']);
    });

    test('alphabetical sorts by series name', () {
      final sorted = sortShelfSeriesForDisplay(
        series,
        CollectionShelfSort.alphabetical,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });

    test('figureCount sorts descending by series figureCount', () {
      final sorted = sortShelfSeriesForDisplay(
        series,
        CollectionShelfSort.figureCount,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['b', 'c', 'a']);
    });

    test('figureCount sorts all series globally (ignores IP totals)', () {
      ShelfSeries withCount({
        required String id,
        required String name,
        required String ipId,
        required int count,
      }) {
        return testShelfSeries(
          id: id,
          name: name,
          taxonomyIpId: ipId,
          ipName: ipId == 'disney' ? 'Disney' : 'Nommi',
          figures: [
            for (var i = 0; i < count; i++)
              ShelfFigure(
                id: '${id}_fig_$i',
                seriesId: id,
                name: 'Figure $i',
                rarity: 'Regular',
                isSecret: false,
                catalogFigureTemplateId: '${id}_tpl_$i',
              ),
          ],
        );
      }

      final sorted = sortShelfSeriesForDisplay(
        [
          withCount(id: 'da', name: 'Disney A', ipId: 'disney', count: 20),
          withCount(id: 'na', name: 'Nommi A', ipId: 'nommi', count: 18),
          withCount(id: 'db', name: 'Disney B', ipId: 'disney', count: 17),
        ],
        CollectionShelfSort.figureCount,
        states,
      );
      // Flat: 20, 18, 17 — not Disney (37) then Nommi.
      expect(sorted.map((s) => s.id).toList(), ['da', 'na', 'db']);
    });

    test('completion sorts by series ratio descending', () {
      final s1 = _series(id: 's1', name: 'One', figureCount: 4);
      final s2 = _series(id: 's2', name: 'Two', figureCount: 4);
      final states = {
        ..._ownedCount(s1, 3),
        ..._ownedCount(s2, 1),
      };
      final sorted = sortShelfSeriesForDisplay(
        [s2, s1],
        CollectionShelfSort.completion,
        states,
      );
      expect(sorted.first.id, 's1');
    });

    test('completion prefers Master Complete over Complete', () {
      final master = testShelfSeries(
        id: 'master',
        name: 'Zebra Master',
        figures: [
          const ShelfFigure(
            id: 'm_r0',
            seriesId: 'master',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'm_sec',
            seriesId: 'master',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final complete = testShelfSeries(
        id: 'complete',
        name: 'Alpha Complete',
        figures: [
          const ShelfFigure(
            id: 'c_r0',
            seriesId: 'complete',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'c_sec',
            seriesId: 'complete',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final states = {
        ..._ownedAll(master),
        'c_r0': TrackedFigure(
          figureId: 'c_r0',
          state: FigureCollectionState.owned,
        ),
      };
      final sorted = sortShelfSeriesForDisplay(
        [complete, master],
        CollectionShelfSort.completion,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['master', 'complete']);
    });

    test('completion keeps name order among Master Complete peers', () {
      ShelfSeries masterNamed(String id, String name) {
        return testShelfSeries(
          id: id,
          name: name,
          figures: [
            ShelfFigure(
              id: '${id}_r',
              seriesId: id,
              name: 'R',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: '${id}_sec',
              seriesId: id,
              name: 'Chase',
              rarity: 'Secret',
              isSecret: true,
            ),
          ],
        );
      }

      final zebra = masterNamed('z', 'Zebra');
      final alpha = masterNamed('a', 'Alpha');
      final states = {..._ownedAll(zebra), ..._ownedAll(alpha)};
      final sorted = sortShelfSeriesForDisplay(
        [zebra, alpha],
        CollectionShelfSort.completion,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a', 'z']);
    });

    test('completion keeps name order among Complete peers', () {
      final zebra = _series(id: 'z', name: 'Zebra', figureCount: 2);
      final alpha = _series(id: 'a', name: 'Alpha', figureCount: 2);
      final states = {..._ownedAll(zebra), ..._ownedAll(alpha)};
      final sorted = sortShelfSeriesForDisplay(
        [zebra, alpha],
        CollectionShelfSort.completion,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a', 'z']);
    });

    test('completion prefers Near Complete over lower In Progress', () {
      // 4 slots: 4 owned → ratio 1.0 complete; 3/4 = 0.75 not near;
      // use 6 slots: 6*0.85=5.1 → 6 owned of regular path with 6 figs:
      // near = progressRatio >= 0.85 and not complete → 6 regulars, own 6? that's complete.
      // 5 of 6 = ~0.833 < 0.85; 6 of 7 ≈ 0.857 near.
      final near = _series(id: 'near', name: 'Near', figureCount: 7);
      final low = _series(id: 'low', name: 'Low', figureCount: 7);
      final states = {
        ..._ownedCount(near, 6), // 6/7 ≈ 0.857
        ..._ownedCount(low, 2),
      };
      final sorted = sortShelfSeriesForDisplay(
        [low, near],
        CollectionShelfSort.completion,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['near', 'low']);
    });

    test('completion mixed tiers: Master → Complete → Near → In Progress', () {
      final master = testShelfSeries(
        id: 'master',
        name: 'Master',
        figures: [
          const ShelfFigure(
            id: 'm_r',
            seriesId: 'master',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'm_sec',
            seriesId: 'master',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final complete = _series(id: 'complete', name: 'Complete', figureCount: 3);
      final near = _series(id: 'near', name: 'Near', figureCount: 7);
      final low = _series(id: 'low', name: 'Low', figureCount: 4);
      final states = {
        ..._ownedAll(master),
        ..._ownedAll(complete),
        ..._ownedCount(near, 6),
        ..._ownedCount(low, 1),
      };
      final sorted = sortShelfSeriesForDisplay(
        [low, complete, near, master],
        CollectionShelfSort.completion,
        states,
      );
      expect(
        sorted.map((s) => s.id).toList(),
        ['master', 'complete', 'near', 'low'],
      );
    });

    test('completion sorts all series globally (ignores IP weighted ratio)', () {
      ShelfSeries withCount({
        required String id,
        required String name,
        required String ipId,
        required int count,
      }) {
        return testShelfSeries(
          id: id,
          name: name,
          taxonomyIpId: ipId,
          ipName: ipId == 'disney' ? 'Disney' : 'Nommi',
          figures: [
            for (var i = 0; i < count; i++)
              ShelfFigure(
                id: '${id}_fig_$i',
                seriesId: id,
                name: 'Figure $i',
                rarity: 'Regular',
                isSecret: false,
                catalogFigureTemplateId: '${id}_tpl_$i',
              ),
          ],
        );
      }

      final disneyDone = withCount(
        id: 'da',
        name: 'Disney Done',
        ipId: 'disney',
        count: 10,
      );
      final disneyOpen = withCount(
        id: 'db',
        name: 'Disney Open',
        ipId: 'disney',
        count: 10,
      );
      final nommiAlmost = withCount(
        id: 'na',
        name: 'Nommi Almost',
        ipId: 'nommi',
        count: 10,
      );
      final states = {
        ..._ownedAll(disneyDone),
        ..._ownedCount(nommiAlmost, 9),
      };

      final sorted = sortShelfSeriesForDisplay(
        [disneyDone, nommiAlmost, disneyOpen],
        CollectionShelfSort.completion,
        states,
      );

      // Flat by series ratio: 1.0, 0.9, 0.0 — not Nommi-first via IP weighting.
      expect(sorted.map((s) => s.id).toList(), ['da', 'na', 'db']);
    });

    test('alphabetical is case-insensitive for series names', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(id: 'z', name: 'zebra', ipId: 'zeta', ipLabel: 'ZETA'),
          _ipSeries(id: 'a', name: 'Alpha', ipId: 'alpha', ipLabel: 'alpha'),
        ],
        CollectionShelfSort.alphabetical,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a', 'z']);
    });

    test('alphabetical tie-breaks equal series names by shelf id', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(
            id: 'z_id',
            name: 'Same Name',
            ipId: 'solo',
            ipLabel: 'Solo',
          ),
          _ipSeries(
            id: 'a_id',
            name: 'Same Name',
            ipId: 'solo',
            ipLabel: 'Solo',
          ),
        ],
        CollectionShelfSort.alphabetical,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a_id', 'z_id']);
    });

    test('alphabetical does not group by equal IP labels', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(
            id: 's2',
            name: 'Series B',
            ipId: 'zeta',
            ipLabel: 'Twin',
          ),
          _ipSeries(
            id: 's1',
            name: 'Series A',
            ipId: 'alpha',
            ipLabel: 'Twin',
          ),
        ],
        CollectionShelfSort.alphabetical,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['s1', 's2']);
    });

    test('figureCount tie-breaks equal counts by series name A-Z', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(
            id: 'z1',
            name: 'Z Series',
            ipId: 'zeta',
            ipLabel: 'Zeta',
            figureCount: 5,
          ),
          _ipSeries(
            id: 'a1',
            name: 'A Series',
            ipId: 'alpha',
            ipLabel: 'Alpha',
            figureCount: 5,
          ),
        ],
        CollectionShelfSort.figureCount,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a1', 'z1']);
    });

    test('figureCount tie-breaks equal series counts by name A-Z', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(
            id: 'b',
            name: 'Bravo',
            ipId: 'solo',
            ipLabel: 'Solo',
            figureCount: 4,
          ),
          _ipSeries(
            id: 'a',
            name: 'Alpha',
            ipId: 'solo',
            ipLabel: 'Solo',
            figureCount: 4,
          ),
        ],
        CollectionShelfSort.figureCount,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a', 'b']);
    });

    test('figureCount tie-breaks equal counts and names by shelf id', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(
            id: 'z_id',
            name: 'Same',
            ipId: 'solo',
            ipLabel: 'Solo',
            figureCount: 4,
          ),
          _ipSeries(
            id: 'a_id',
            name: 'Same',
            ipId: 'solo',
            ipLabel: 'Solo',
            figureCount: 4,
          ),
        ],
        CollectionShelfSort.figureCount,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a_id', 'z_id']);
    });

    test('completion tie-breaks equal series ratios by name A-Z', () {
      final a = _ipSeries(
        id: 'b',
        name: 'Bravo',
        ipId: 'solo',
        ipLabel: 'Solo',
        figureCount: 4,
      );
      final b = _ipSeries(
        id: 'a',
        name: 'Alpha',
        ipId: 'solo',
        ipLabel: 'Solo',
        figureCount: 4,
      );
      final owned = {
        ..._ownedCount(a, 2),
        ..._ownedCount(b, 2),
      };
      final sorted = sortShelfSeriesForDisplay(
        [a, b],
        CollectionShelfSort.completion,
        owned,
      );
      expect(sorted.map((s) => s.id).toList(), ['a', 'b']);
    });

    test('completion tie-breaks equal ratios and names by shelf id', () {
      final z = _ipSeries(
        id: 'z_id',
        name: 'Same',
        ipId: 'solo',
        ipLabel: 'Solo',
        figureCount: 4,
      );
      final a = _ipSeries(
        id: 'a_id',
        name: 'Same',
        ipId: 'solo',
        ipLabel: 'Solo',
        figureCount: 4,
      );
      final owned = {
        ..._ownedCount(z, 2),
        ..._ownedCount(a, 2),
      };
      final sorted = sortShelfSeriesForDisplay(
        [z, a],
        CollectionShelfSort.completion,
        owned,
      );
      expect(sorted.map((s) => s.id).toList(), ['a_id', 'z_id']);
    });

    test('completion sorts zero-figure series after in-progress rows', () {
      final empty = testShelfSeries(
        id: 'empty',
        name: 'Empty',
        taxonomyIpId: 'solo',
        ipName: 'Solo',
        figures: const [],
      );
      final partial = _ipSeries(
        id: 'partial',
        name: 'Partial',
        ipId: 'solo',
        ipLabel: 'Solo',
        figureCount: 4,
      );
      final sorted = sortShelfSeriesForDisplay(
        [empty, partial],
        CollectionShelfSort.completion,
        _ownedCount(partial, 2),
      );
      expect(sorted.map((s) => s.id).toList(), ['partial', 'empty']);
    });

    test('completion tie-breaks equal ratios by series name A-Z', () {
      final alpha = _ipSeries(
        id: 'a1',
        name: 'A One',
        ipId: 'alpha',
        ipLabel: 'Alpha',
        figureCount: 4,
      );
      final zeta = _ipSeries(
        id: 'z1',
        name: 'Z One',
        ipId: 'zeta',
        ipLabel: 'Zeta',
        figureCount: 4,
      );
      final owned = {
        ..._ownedCount(alpha, 2),
        ..._ownedCount(zeta, 2),
      };
      final sorted = sortShelfSeriesForDisplay(
        [zeta, alpha],
        CollectionShelfSort.completion,
        owned,
      );
      expect(sorted.map((s) => s.id).toList(), ['a1', 'z1']);
    });

    test('empty input returns empty for every sort mode', () {
      const states = <String, TrackedFigure>{};
      for (final sort in CollectionShelfSort.values) {
        expect(
          sortShelfSeriesForDisplay(const [], sort, states),
          isEmpty,
        );
      }
    });
  });

  group('flat sort does not preserve IP adjacency', () {
    const states = <String, TrackedFigure>{};

    test('alphabetical interleaves series across IPs by name', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(id: 'da', name: 'Disney A', ipId: 'disney', ipLabel: 'Disney'),
          _ipSeries(id: 'na', name: 'Nommi A', ipId: 'nommi', ipLabel: 'Nommi'),
          _ipSeries(id: 'db', name: 'Disney B', ipId: 'disney', ipLabel: 'Disney'),
        ],
        CollectionShelfSort.alphabetical,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['da', 'db', 'na']);
    });

    test('figureCount orders by series count across IPs', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(
            id: 'da',
            name: 'Disney A',
            ipId: 'disney',
            ipLabel: 'Disney',
            figureCount: 20,
          ),
          _ipSeries(
            id: 'na',
            name: 'Nommi A',
            ipId: 'nommi',
            ipLabel: 'Nommi',
            figureCount: 18,
          ),
          _ipSeries(
            id: 'db',
            name: 'Disney B',
            ipId: 'disney',
            ipLabel: 'Disney',
            figureCount: 17,
          ),
        ],
        CollectionShelfSort.figureCount,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['da', 'na', 'db']);
    });

    test('completion orders by series ratio across IPs', () {
      final disneyDone = _ipSeries(
        id: 'da',
        name: 'Disney Done',
        ipId: 'disney',
        ipLabel: 'Disney',
        figureCount: 10,
      );
      final disneyOpen = _ipSeries(
        id: 'db',
        name: 'Disney Open',
        ipId: 'disney',
        ipLabel: 'Disney',
        figureCount: 10,
      );
      final nommiAlmost = _ipSeries(
        id: 'na',
        name: 'Nommi Almost',
        ipId: 'nommi',
        ipLabel: 'Nommi',
        figureCount: 10,
      );
      final owned = {
        ..._ownedAll(disneyDone),
        ..._ownedCount(nommiAlmost, 9),
      };
      final sorted = sortShelfSeriesForDisplay(
        [disneyDone, nommiAlmost, disneyOpen],
        CollectionShelfSort.completion,
        owned,
      );
      expect(sorted.map((s) => s.id).toList(), ['da', 'na', 'db']);
    });
  });

  group('browse pipeline sort interactions', () {
    test('partition preserves shelf order within each bucket', () {
      final complete = _series(id: 'done', name: 'Done', figureCount: 2);
      final openNew = _series(id: 'open_new', name: 'Open New', figureCount: 2);
      final openOld = _series(id: 'open_old', name: 'Open Old', figureCount: 2);
      final states = {..._ownedAll(complete)};
      final shelf = [openNew, complete, openOld];

      final (inProgress, completed) = partitionShelfSeries(shelf, states);
      expect(inProgress.map((s) => s.id).toList(), ['open_new', 'open_old']);
      expect(completed.map((s) => s.id).toList(), ['done']);

      final display = sortShelfSeriesForDisplay(
        inProgress,
        CollectionShelfSort.recentlyAdded,
        states,
      );
      expect(display.map((s) => s.id).toList(), ['open_new', 'open_old']);
    });

    test('brand filter then figureCount keeps flat series order', () {
      final pop = testShelfSeries(
        id: 'pop',
        name: 'Pop Series',
        brand: 'POP MART',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'disney',
        ipName: 'Disney',
        figures: [
          for (var i = 0; i < 10; i++)
            ShelfFigure(
              id: 'pop_fig_$i',
              seriesId: 'pop',
              name: 'F $i',
              rarity: 'Regular',
              isSecret: false,
              catalogFigureTemplateId: 'pop_tpl_$i',
            ),
        ],
      );
      final other = testShelfSeries(
        id: 'other',
        name: 'Other Brand',
        brand: 'Other Co',
        taxonomyIpId: 'nommi',
        ipName: 'Nommi',
        figures: [
          for (var i = 0; i < 20; i++)
            ShelfFigure(
              id: 'other_fig_$i',
              seriesId: 'other',
              name: 'F $i',
              rarity: 'Regular',
              isSecret: false,
              catalogFigureTemplateId: 'other_tpl_$i',
            ),
        ],
      );
      const states = <String, TrackedFigure>{};
      final shelf = [other, pop];
      final brandFiltered = shelfSeriesVisibleForBrandFilter(
        shelf,
        collectionBrandFilterKeyForSeries(pop),
      );
      final sorted = sortShelfSeriesForDisplay(
        brandFiltered,
        CollectionShelfSort.figureCount,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['pop']);
    });

    test('figureCount order survives search filter and clear', () {
      final sorted = sortShelfSeriesForDisplay(
        [
          _ipSeries(
            id: 'da',
            name: 'Disney A',
            ipId: 'disney',
            ipLabel: 'Disney',
            figureCount: 20,
          ),
          _ipSeries(
            id: 'na',
            name: 'Nommi A',
            ipId: 'nommi',
            ipLabel: 'Nommi',
            figureCount: 18,
          ),
          _ipSeries(
            id: 'db',
            name: 'Disney B',
            ipId: 'disney',
            ipLabel: 'Disney',
            figureCount: 17,
          ),
        ],
        CollectionShelfSort.figureCount,
        const {},
      );
      final filtered = filterShelfSeriesBySearch(sorted, 'Disney');
      expect(filtered.map((s) => s.id).toList(), ['da', 'db']);
      final restored = filterShelfSeriesBySearch(sorted, '');
      expect(restored.map((s) => s.id).toList(), ['da', 'na', 'db']);
    });
  });

  group('search preserves sort', () {
    test('alphabetical order survives filter and clear', () {
      final series = [
        _series(id: 'z', name: 'Zeta Labubu'),
        _series(id: 'a', name: 'Alpha Labubu'),
        _series(id: 'm', name: 'Mango'),
      ];
      const states = <String, TrackedFigure>{};

      final sorted = sortShelfSeriesForDisplay(
        series,
        CollectionShelfSort.alphabetical,
        states,
      );
      final filtered = filterShelfSeriesBySearch(sorted, 'Labubu');
      expect(filtered.map((s) => s.id).toList(), ['a', 'z']);

      final restored = filterShelfSeriesBySearch(sorted, '');
      expect(restored.map((s) => s.id).toList(), ['a', 'm', 'z']);
    });
  });

  group('partitionShelfSeries', () {
    test('splits complete and in-progress series', () {
      final complete = _series(id: 'done', name: 'Done', figureCount: 2);
      final partial = _series(id: 'open', name: 'Open', figureCount: 3);
      final states = {
        ..._ownedAll(complete),
        ..._ownedCount(partial, 1),
      };

      final (inProgress, completed) = partitionShelfSeries(
        [complete, partial],
        states,
      );

      expect(inProgress.map((s) => s.id), ['open']);
      expect(completed.map((s) => s.id), ['done']);
    });
  });

  group('isShelfSeriesComplete', () {
    test('false when figure count is zero', () {
      final empty = testShelfSeries(
        id: 'empty',
        figures: const [],
      );
      expect(isShelfSeriesComplete(empty, const {}), isFalse);
    });
  });

  group('CollectionShelfSortLabels', () {
    test('alphabetical menu label is Alphabetical (A–Z)', () {
      expect(
        CollectionShelfSort.alphabetical.menuLabel,
        'Alphabetical (A–Z)',
      );
    });

    test('completion menu label is Completion', () {
      expect(CollectionShelfSort.completion.menuLabel, 'Completion');
    });
  });

  group('CollectionProgressVoice stat lines', () {
    test('in-progress series shows owned/total and missing', () {
      final series = _series(id: 's', name: 'Series', figureCount: 12);
      final states = _ownedCount(series, 7);
      const progress = SeriesProgressCounts(
        owned: 7,
        wishlist: 0,
        missing: 5,
      );

      expect(
        CollectionProgressVoice.seriesStatPrimaryLine(
          series: series,
          progress: progress,
          figureStates: states,
        ),
        '7 / 12',
      );
      expect(
        CollectionProgressVoice.seriesStatSecondaryLine(
          series: series,
          progress: progress,
          figureStates: states,
        ),
        'Missing 5',
      );
    });

    test('complete series shows checkmark and full tally', () {
      final series = _series(id: 's', name: 'Series', figureCount: 12);
      const progress = SeriesProgressCounts(
        owned: 12,
        wishlist: 0,
        missing: 0,
      );
      final states = _ownedAll(series);

      expect(
        CollectionProgressVoice.seriesStatPrimaryLine(
          series: series,
          progress: progress,
          figureStates: states,
        ),
        '✓ Complete',
      );
      expect(
        CollectionProgressVoice.seriesStatSecondaryLine(
          series: series,
          progress: progress,
          figureStates: states,
        ),
        '',
      );
    });

    test('regular complete with secret missing shows chase whisper', () {
      final series = testShelfSeries(
        id: 'macaron',
        name: 'Macaron',
        figures: [
          for (var i = 0; i < 3; i++)
            ShelfFigure(
              id: 'reg_$i',
              seriesId: 'macaron',
              name: 'R $i',
              rarity: 'Regular',
              isSecret: false,
            ),
          const ShelfFigure(
            id: 'sec_0',
            seriesId: 'macaron',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final states = {
        for (var i = 0; i < 3; i++)
          'reg_$i': TrackedFigure(
            figureId: 'reg_$i',
            state: FigureCollectionState.owned,
          ),
      };
      const progress = SeriesProgressCounts(
        owned: 3,
        wishlist: 0,
        missing: 1,
      );

      expect(
        CollectionProgressVoice.seriesStatPrimaryLine(
          series: series,
          progress: progress,
          figureStates: states,
        ),
        '✓ Complete',
      );
      expect(
        CollectionProgressVoice.seriesStatSecondaryLine(
          series: series,
          progress: progress,
          figureStates: states,
        ),
        '☆ Secret Figure still to find',
      );
    });

    test('master complete shows crown badge', () {
      final series = testShelfSeries(
        id: 'macaron',
        name: 'Macaron',
        figures: [
          const ShelfFigure(
            id: 'reg_0',
            seriesId: 'macaron',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'sec_0',
            seriesId: 'macaron',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final states = {
        'reg_0': const TrackedFigure(
          figureId: 'reg_0',
          state: FigureCollectionState.owned,
        ),
        'sec_0': const TrackedFigure(
          figureId: 'sec_0',
          state: FigureCollectionState.owned,
        ),
      };
      const progress = SeriesProgressCounts(
        owned: 2,
        wishlist: 0,
        missing: 0,
      );

      expect(
        CollectionProgressVoice.seriesStatPrimaryLine(
          series: series,
          progress: progress,
          figureStates: states,
        ),
        '👑 Master Complete',
      );
    });
  });

  group('partitionShelfSeries secrets', () {
    test('regular complete without secret lands in completed bucket', () {
      final series = testShelfSeries(
        id: 's',
        name: 'Series',
        figures: [
          const ShelfFigure(
            id: 'reg_0',
            seriesId: 's',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'sec_0',
            seriesId: 's',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final states = {
        'reg_0': const TrackedFigure(
          figureId: 'reg_0',
          state: FigureCollectionState.owned,
        ),
      };

      final (inProgress, completed) = partitionShelfSeries([series], states);
      expect(inProgress, isEmpty);
      expect(completed.map((s) => s.id), ['s']);
    });
  });

  group('Recently Added round-trip safety', () {
    test('source shelf list is never mutated across sort modes', () {
      final shelf = [
        _series(id: 'newest', name: 'Newest', figureCount: 4),
        _series(id: 'middle', name: 'Middle', figureCount: 2),
        _series(id: 'oldest', name: 'Oldest', figureCount: 6),
      ];
      final originalIds = shelf.map((s) => s.id).toList();
      const states = <String, TrackedFigure>{};

      for (final sort in CollectionShelfSort.values) {
        final searched = filterShelfSeriesBySearch(shelf, '');
        expect(identical(searched, shelf), isTrue);
        final (inProgress, _) = partitionShelfSeries(searched, states);
        sortShelfSeriesForDisplay(inProgress, sort, states);
      }

      expect(shelf.map((s) => s.id).toList(), originalIds);
    });

    test('Recently Added restores shelf order after other sort modes', () {
      final shelf = [
        _series(id: 'newest', name: 'Newest', figureCount: 4),
        _series(id: 'middle', name: 'Middle', figureCount: 2),
        _series(id: 'oldest', name: 'Oldest', figureCount: 6),
      ];
      const states = <String, TrackedFigure>{};
      final sortModes = [
        CollectionShelfSort.figureCount,
        CollectionShelfSort.completion,
        CollectionShelfSort.alphabetical,
        CollectionShelfSort.recentlyAdded,
      ];

      for (final sort in sortModes) {
        final searched = filterShelfSeriesBySearch(shelf, '');
        final (inProgress, _) = partitionShelfSeries(searched, states);
        final display = sortShelfSeriesForDisplay(inProgress, sort, states);
        if (sort == CollectionShelfSort.recentlyAdded) {
          expect(
            display.map((s) => s.id).toList(),
            ['newest', 'middle', 'oldest'],
          );
        }
      }
    });

    test('recentlyAdded preserves flat order when IPs interleave on shelf', () {
      const states = <String, TrackedFigure>{};
      final shelf = [
        _ipSeries(id: 'n2', name: 'Nommi B', ipId: 'nommi', ipLabel: 'Nommi'),
        _ipSeries(id: 'd1', name: 'Disney A', ipId: 'disney', ipLabel: 'Disney'),
        _ipSeries(id: 'n1', name: 'Nommi A', ipId: 'nommi', ipLabel: 'Nommi'),
      ];
      final sorted = sortShelfSeriesForDisplay(
        shelf,
        CollectionShelfSort.recentlyAdded,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['n2', 'd1', 'n1']);
    });

    test('recentlyAdded restores shelf order across repeated sort cycles', () {
      final shelf = [
        _series(id: 'newest', name: 'Newest', figureCount: 4),
        _series(id: 'middle', name: 'Middle', figureCount: 2),
        _series(id: 'oldest', name: 'Oldest', figureCount: 6),
      ];
      const states = <String, TrackedFigure>{};
      const expected = ['newest', 'middle', 'oldest'];
      const cycle = [
        CollectionShelfSort.figureCount,
        CollectionShelfSort.alphabetical,
        CollectionShelfSort.completion,
        CollectionShelfSort.recentlyAdded,
      ];

      for (var i = 0; i < 3; i++) {
        final (inProgress, _) = partitionShelfSeries(shelf, states);
        for (final sort in cycle) {
          final display = sortShelfSeriesForDisplay(inProgress, sort, states);
          if (sort == CollectionShelfSort.recentlyAdded) {
            expect(display.map((s) => s.id).toList(), expected);
          }
        }
      }
    });
  });

  group('CollectionShelfUiPrefsStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns defaults when empty', () async {
      final prefs = await CollectionShelfUiPrefsStorage.load();
      expect(prefs.sort, CollectionShelfSort.recentlyAdded);
      expect(prefs.inProgressSectionExpanded, isTrue);
      expect(prefs.completedSectionExpanded, isFalse);
      expect(prefs.collapsedIpSectionKeys, isEmpty);
    });

    test('save then load round-trips sort and collapse keys', () async {
      await CollectionShelfUiPrefsStorage.save(
        const CollectionShelfUiPrefs(
          sort: CollectionShelfSort.alphabetical,
          inProgressSectionExpanded: false,
          completedSectionExpanded: true,
          collapsedIpSectionKeys: {'ip:labubu'},
        ),
      );
      final prefs = await CollectionShelfUiPrefsStorage.load();
      expect(prefs.sort, CollectionShelfSort.alphabetical);
      expect(prefs.inProgressSectionExpanded, isFalse);
      expect(prefs.completedSectionExpanded, isTrue);
      expect(prefs.collapsedIpSectionKeys, {'ip:labubu'});
    });
  });
}
