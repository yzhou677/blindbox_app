import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filter_matching.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfFigure _fig(
  String id,
  String seriesId, {
  bool secret = false,
  String name = 'Fig',
}) {
  return ShelfFigure(
    id: id,
    seriesId: seriesId,
    name: name,
    rarity: secret ? '1:144' : 'Regular',
    isSecret: secret,
  );
}

TrackedFigure _owned(String id, {int qty = 1, int? updatedAtMicros}) {
  return TrackedFigure(
    figureId: id,
    state: FigureCollectionState.owned,
    ownedQuantity: qty,
    updatedAtMicros: updatedAtMicros,
  );
}

TrackedFigure _wish(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.wishlist);

void main() {
  group('Progress filters', () {
    test('In Progress matches incomplete series including zero-owned', () {
      final series = testShelfSeries(
        id: 'ip',
        figures: [_fig('a', 'ip'), _fig('b', 'ip')],
      );
      expect(
        shelfSeriesMatchesProgressFilter(
          series,
          const {},
          CollectionShelfProgressFilter.inProgress,
        ),
        isTrue,
      );
      final states = {'a': _owned('a')};
      expect(
        shelfSeriesMatchesProgressFilter(
          series,
          states,
          CollectionShelfProgressFilter.inProgress,
        ),
        isTrue,
      );
      expect(
        shelfSeriesMatchesProgressFilter(
          series,
          states,
          CollectionShelfProgressFilter.completed,
        ),
        isFalse,
      );
    });

    test('Completed matches regular-complete non-master', () {
      final series = testShelfSeries(
        id: 'c',
        figures: [
          _fig('r1', 'c'),
          _fig('r2', 'c'),
          _fig('s1', 'c', secret: true),
        ],
      );
      final states = {'r1': _owned('r1'), 'r2': _owned('r2')};
      expect(
        shelfSeriesMatchesProgressFilter(
          series,
          states,
          CollectionShelfProgressFilter.completed,
        ),
        isTrue,
      );
      expect(
        shelfSeriesMatchesProgressFilter(
          series,
          states,
          CollectionShelfProgressFilter.masterComplete,
        ),
        isFalse,
      );
    });

    test('Completed includes Master; Master does not broaden to Completed-only',
        () {
      final series = testShelfSeries(
        id: 'm',
        figures: [_fig('r1', 'm'), _fig('s1', 'm', secret: true)],
      );
      final masterStates = {'r1': _owned('r1'), 's1': _owned('s1')};
      expect(
        shelfSeriesMatchesProgressFilter(
          series,
          masterStates,
          CollectionShelfProgressFilter.masterComplete,
        ),
        isTrue,
      );
      // Completed is the broader set — Master series also match Completed.
      expect(
        shelfSeriesMatchesProgressFilter(
          series,
          masterStates,
          CollectionShelfProgressFilter.completed,
        ),
        isTrue,
      );

      final regularComplete = testShelfSeries(
        id: 'c',
        figures: [
          _fig('r1', 'c'),
          _fig('r2', 'c'),
          _fig('s1', 'c', secret: true),
        ],
      );
      final regularStates = {'r1': _owned('r1'), 'r2': _owned('r2')};
      expect(
        shelfSeriesMatchesProgressFilter(
          regularComplete,
          regularStates,
          CollectionShelfProgressFilter.completed,
        ),
        isTrue,
      );
      expect(
        shelfSeriesMatchesProgressFilter(
          regularComplete,
          regularStates,
          CollectionShelfProgressFilter.masterComplete,
        ),
        isFalse,
      );
    });
  });

  group('Collection Attributes', () {
    test('Has Duplicates', () {
      final series = testShelfSeries(
        id: 'd',
        figures: [_fig('f', 'd'), _fig('g', 'd')],
      );
      expect(
        applyCollectionShelfFilters(
          [series],
          {'f': _owned('f', qty: 2)},
          const CollectionShelfFilters(hasDuplicates: true),
        ),
        hasLength(1),
      );
      expect(
        applyCollectionShelfFilters(
          [series],
          {'f': _owned('f', qty: 1)},
          const CollectionShelfFilters(hasDuplicates: true),
        ),
        isEmpty,
      );
    });

    test('Has Wishlist Items', () {
      final series = testShelfSeries(
        id: 'w',
        figures: [_fig('f', 'w'), _fig('g', 'w')],
      );
      expect(
        applyCollectionShelfFilters(
          [series],
          {'f': _owned('f'), 'g': _wish('g')},
          const CollectionShelfFilters(hasWishlistItems: true),
        ),
        hasLength(1),
      );
    });

    test('Secret Owned ignores quantity', () {
      final series = testShelfSeries(
        id: 'so',
        figures: [_fig('r', 'so'), _fig('s', 'so', secret: true)],
      );
      expect(
        applyCollectionShelfFilters(
          [series],
          {'s': _owned('s', qty: 3)},
          const CollectionShelfFilters(secretOwned: true),
        ),
        hasLength(1),
      );
    });

    test('Secret Missing requires secret slots and incomplete secrets', () {
      final series = testShelfSeries(
        id: 'sm',
        figures: [
          _fig('r', 'sm'),
          _fig('s1', 'sm', secret: true),
          _fig('s2', 'sm', secret: true),
        ],
      );
      expect(
        applyCollectionShelfFilters(
          [series],
          {'s1': _owned('s1')},
          const CollectionShelfFilters(secretMissing: true),
        ),
        hasLength(1),
      );
      expect(
        applyCollectionShelfFilters(
          [series],
          {'s1': _owned('s1'), 's2': _owned('s2')},
          const CollectionShelfFilters(secretMissing: true),
        ),
        isEmpty,
      );
    });

    test('Custom Series', () {
      final custom = testShelfSeries(
        id: 'custom',
        catalogTemplateId: null,
        figures: [_fig('f', 'custom')],
      );
      final catalogued = testShelfSeries(id: 'cat');
      expect(
        applyCollectionShelfFilters(
          [custom, catalogued],
          const {},
          const CollectionShelfFilters(customSeries: true),
        ).map((s) => s.id),
        ['custom'],
      );
    });
  });

  group('Combination semantics', () {
    final pop = testShelfSeries(
      id: 'pop',
      brand: 'POP MART',
      taxonomyBrandId: 'pop_mart',
      ipName: 'Hirono',
      taxonomyIpId: 'hirono',
      figures: [_fig('p1', 'pop'), _fig('p2', 'pop', secret: true)],
    );
    final top = testShelfSeries(
      id: 'top',
      brand: 'TOP TOY',
      taxonomyBrandId: 'toptoy',
      ipName: 'Skullpanda',
      taxonomyIpId: 'skullpanda',
      figures: [_fig('t1', 'top'), _fig('t2', 'top')],
    );
    final states = {'p1': _owned('p1', qty: 2), 't1': _owned('t1')};

    test('Brand is single-select (legacy multi ids collapse to first)', () {
      final filtered = applyCollectionShelfFilters(
        [pop, top],
        states,
        CollectionShelfFilters(brandIds: {'popmart', 'toptoy'}),
      );
      expect(filtered.map((s) => s.id).toSet(), {'pop'});
    });

    test('IP is single-select (legacy multi ids collapse to first)', () {
      final filtered = applyCollectionShelfFilters(
        [pop, top],
        states,
        CollectionShelfFilters(ipIds: {'hirono', 'skullpanda'}),
      );
      expect(filtered.map((s) => s.id).toSet(), {'pop'});
    });

    test('multiple attributes use AND', () {
      final filtered = applyCollectionShelfFilters(
        [pop, top],
        states,
        const CollectionShelfFilters(hasDuplicates: true, secretMissing: true),
      );
      expect(filtered.map((s) => s.id), ['pop']);
    });

    test('different sections use AND', () {
      expect(
        applyCollectionShelfFilters(
          [pop, top],
          states,
          CollectionShelfFilters(brandIds: {'popmart'}, hasDuplicates: true),
        ).map((s) => s.id),
        ['pop'],
      );
      expect(
        applyCollectionShelfFilters(
          [pop, top],
          states,
          CollectionShelfFilters(brandIds: {'toptoy'}, hasDuplicates: true),
        ),
        isEmpty,
      );
    });

    test('search combines with active filters via pipeline intersect', () {
      final filtered = applyCollectionShelfFilters(
        [pop, top],
        states,
        CollectionShelfFilters(brandIds: {'popmart'}),
      );
      expect(filterShelfSeriesBySearch(filtered, 'Hirono').map((s) => s.id), [
        'pop',
      ]);
      expect(filterShelfSeriesBySearch(filtered, 'Skullpanda'), isEmpty);
    });
  });

  group('Filter model', () {
    test('activeCount counts Brand/IP once each (single-select)', () {
      const filters = CollectionShelfFilters(
        progress: CollectionShelfProgressFilter.inProgress,
        hasDuplicates: true,
        brandIds: {'popmart', 'toptoy'},
        ipIds: {'hirono'},
      );
      // progress + hasDuplicates + brand(1 after normalize in activeCount?) 
      // activeCount on raw model: brandIds.length was 2 before; now brandIds counts as 1 if non-empty
      expect(filters.activeCount, 4);
    });

    test('cleared removes every filter', () {
      const filters = CollectionShelfFilters(
        hasDuplicates: true,
        brandIds: {'popmart'},
        progress: CollectionShelfProgressFilter.completed,
      );
      expect(filters.cleared(), CollectionShelfFilters.empty);
      expect(filters.cleared().activeCount, 0);
    });
  });
}
