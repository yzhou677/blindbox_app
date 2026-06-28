import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
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

    test('alphabetical sorts IP groups A-Z then series within each IP', () {
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
      expect(sorted.map((s) => s.id).toList(), ['d1', 'd2', 'n1', 'n2']);
    });

    test('alphabetical sorts by series name within a single IP', () {
      final sorted = sortShelfSeriesForDisplay(
        series,
        CollectionShelfSort.alphabetical,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });

    test('figureCount sorts descending', () {
      final sorted = sortShelfSeriesForDisplay(
        series,
        CollectionShelfSort.figureCount,
        states,
      );
      expect(sorted.map((s) => s.id).toList(), ['b', 'c', 'a']);
    });

    test('completion sorts by ratio descending', () {
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
      const progress = SeriesProgressCounts(
        owned: 7,
        wishlist: 0,
        missing: 5,
      );

      expect(
        CollectionProgressVoice.seriesStatPrimaryLine(
          series: series,
          progress: progress,
        ),
        '7 / 12',
      );
      expect(
        CollectionProgressVoice.seriesStatSecondaryLine(
          series: series,
          progress: progress,
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

      expect(
        CollectionProgressVoice.seriesStatPrimaryLine(
          series: series,
          progress: progress,
        ),
        '✓ Complete',
      );
      expect(
        CollectionProgressVoice.seriesStatSecondaryLine(
          series: series,
          progress: progress,
        ),
        '12 / 12',
      );
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
