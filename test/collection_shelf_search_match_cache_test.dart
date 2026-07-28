import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  setUp(() {
    ShelfBrowseSearchMatchCache.debugSearchExecutionCount = 0;
    ShelfBrowseSearchMatchCache.debugCacheHitCount = 0;
  });

  test('search match cache runs text search once per query revision', () {
    final shelf = [
      testShelfSeries(id: 'a', name: 'Alpha Series'),
      testShelfSeries(id: 'b', name: 'Bravo Series'),
    ];
    final cache = ShelfBrowseSearchMatchCache();

    final first = cache.matchedIds(shelf: shelf, query: 'Alpha');
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 1);
    expect(first, {'a'});

    final second = cache.matchedIds(shelf: shelf, query: 'Alpha');
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 1);
    expect(ShelfBrowseSearchMatchCache.debugCacheHitCount, 1);
    expect(identical(first, second), isTrue);

    cache.matchedIds(shelf: shelf, query: 'Bravo');
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 2);
  });

  test('empty query caches as match-all (null ids)', () {
    final shelf = [testShelfSeries(id: 'a', name: 'Alpha Series')];
    final cache = ShelfBrowseSearchMatchCache();

    expect(cache.matchedIds(shelf: shelf, query: ''), isNull);
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
    expect(cache.matchedIds(shelf: shelf, query: ''), isNull);
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 0);
    expect(ShelfBrowseSearchMatchCache.debugCacheHitCount, 1);
  });

  test(
    'Brand/IP intersection preserves taxonomy order and search semantics',
    () {
      final alpha = testShelfSeries(
        id: 'a',
        name: 'Alpha Series',
        brand: 'POP MART',
        taxonomyBrandId: 'pop_mart',
        ipName: 'Hirono',
        taxonomyIpId: 'hirono',
      );
      final bravo = testShelfSeries(
        id: 'b',
        name: 'Bravo Series',
        brand: 'POP MART',
        taxonomyBrandId: 'pop_mart',
        ipName: 'Labubu',
        taxonomyIpId: 'the_monsters',
      );
      final charlie = testShelfSeries(
        id: 'c',
        name: 'Charlie Series',
        brand: 'TNT SPACE',
        taxonomyBrandId: 'tntspace',
        ipName: 'Hirono',
        taxonomyIpId: 'hirono',
      );
      final shelf = [alpha, bravo, charlie];

      final legacyVisible = shelfSeriesVisibleForIpFilter(
        shelfSeriesVisibleForBrandFilter(shelf, 'popmart'),
        'hirono',
      );
      final legacy = filterShelfSeriesBySearch(legacyVisible, 'Series');

      final cache = ShelfBrowseSearchMatchCache();
      final matchedIds = cache.matchedIds(shelf: shelf, query: 'Series');
      final brandFiltered = shelfSeriesVisibleForBrandFilter(shelf, 'popmart');
      final taxonomyVisible = shelfSeriesVisibleForIpFilter(
        brandFiltered,
        'hirono',
      );
      final optimized = intersectShelfSeriesBySearchMatchIds(
        taxonomyVisible,
        matchedIds,
      );

      expect(optimized.map((s) => s.id), legacy.map((s) => s.id));
      expect(optimized, [alpha]);
    },
  );

  test('catalog search service reuse does not rebuild on cached hit', () {
    final bundle = const CatalogSeedBundle(
      brands: [],
      ips: [],
      series: [],
      figures: [],
    );
    final service = CatalogSearchService(bundle);
    final shelf = [
      testShelfSeries(id: 'mac', name: 'Macaron', catalogTemplateId: 'macaron'),
    ];
    final cache = ShelfBrowseSearchMatchCache();

    cache.matchedIds(
      shelf: shelf,
      query: 'mac',
      catalog: bundle,
      catalogSearch: service,
    );
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 1);

    cache.matchedIds(
      shelf: shelf,
      query: 'mac',
      catalog: bundle,
      catalogSearch: service,
    );
    expect(ShelfBrowseSearchMatchCache.debugSearchExecutionCount, 1);
  });

  test('intersect with null matched ids returns taxonomy list unchanged', () {
    final rows = [
      testShelfSeries(id: 'a', name: 'A'),
      testShelfSeries(id: 'b', name: 'B'),
    ];
    expect(
      identical(intersectShelfSeriesBySearchMatchIds(rows, null), rows),
      isTrue,
    );
  });
}
