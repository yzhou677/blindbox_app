import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  test('dynamic chip generation uses brands present on shelf', () {
    final series = [
      testShelfSeries(
        id: 'pop',
        brand: 'POP MART',
        taxonomyBrandId: 'pop_mart',
      ),
      testShelfSeries(
        id: 'top',
        brand: 'TOP TOY',
        taxonomyBrandId: 'toptoy',
      ),
      testShelfSeries(
        id: 'custom',
        brand: 'My Wife Brand',
        taxonomyBrandId: 'my_wife_brand',
      ),
    ];

    final options = buildCollectionShelfBrandFilterOptions(series);

    expect(
      options,
      [
        (id: collectionAnyBrandFilterId, label: 'All Brands'),
        (id: 'popmart', label: 'POP MART'),
        (id: 'toptoy', label: 'TOP TOY'),
        (id: 'mywifebrand', label: 'My Wife Brand'),
      ],
    );
  });

  test('POP MART aliases collapse to one POP MART chip', () {
    final series = [
      testShelfSeries(id: 'a', brand: 'POP MART', taxonomyBrandId: 'pop_mart'),
      testShelfSeries(id: 'b', brand: 'Pop Mart', taxonomyBrandId: 'popmart'),
      testShelfSeries(id: 'c', brand: 'Pop-Mart', taxonomyBrandId: 'pop_mart'),
      testShelfSeries(id: 'd', brand: 'POPMART', taxonomyBrandId: 'popmart'),
    ];

    final options = buildCollectionShelfBrandFilterOptions(series);

    expect(options.where((o) => o.id == 'popmart').length, 1);
    expect(options.where((o) => o.label == 'POP MART').length, 1);
  });

  test('TOP TOY aliases collapse to TOP TOY chip', () {
    final series = [
      testShelfSeries(id: 'a', brand: 'TOP TOY', taxonomyBrandId: 'toptoy'),
      testShelfSeries(id: 'b', brand: 'top toy', taxonomyBrandId: 'top_toy'),
      testShelfSeries(id: 'c', brand: 'toptoy', taxonomyBrandId: 'toptoy'),
    ];

    final options = buildCollectionShelfBrandFilterOptions(series);

    expect(options.where((o) => o.id == 'toptoy').length, 1);
    expect(options.where((o) => o.label == 'TOP TOY').length, 1);
  });

  test('ROLIFE aliases collapse to ROLIFE chip', () {
    final series = [
      testShelfSeries(id: 'a', brand: 'ROLIFE', taxonomyBrandId: 'rolife'),
      testShelfSeries(id: 'b', brand: 'RO Life', taxonomyBrandId: 'ro_life'),
    ];

    final options = buildCollectionShelfBrandFilterOptions(series);

    expect(options.where((o) => o.id == 'rolife').length, 1);
    expect(options.where((o) => o.label == 'ROLIFE').length, 1);
  });

  test('unknown custom brand is preserved as its own chip', () {
    final series = [
      testShelfSeries(
        id: 'custom',
        brand: 'Random Figure Club',
        taxonomyBrandId: 'random_figure_club',
      ),
    ];

    final options = buildCollectionShelfBrandFilterOptions(series);

    expect(
      options,
      [
        (id: collectionAnyBrandFilterId, label: 'All Brands'),
        (id: 'randomfigureclub', label: 'Random Figure Club'),
      ],
    );
  });

  test('stale selected chip resets to All', () {
    final options = [
      (id: collectionAnyBrandFilterId, label: 'All Brands'),
      (id: 'popmart', label: 'POP MART'),
    ];

    final next = resolveCollectionBrandFilterSelection(
      selectedBrandFilterId: 'toptoy',
      options: options,
    );

    expect(next, collectionAnyBrandFilterId);
  });

  test('filtering by normalized key returns grouped brand rows', () {
    final pop1 = testShelfSeries(
      id: 'p1',
      brand: 'POP MART',
      taxonomyBrandId: 'pop_mart',
    );
    final pop2 = testShelfSeries(
      id: 'p2',
      brand: 'popmart',
      taxonomyBrandId: 'popmart',
    );
    final top = testShelfSeries(
      id: 't1',
      brand: 'TOP TOY',
      taxonomyBrandId: 'toptoy',
    );

    final filtered = shelfSeriesVisibleForBrandFilter(
      [pop1, pop2, top],
      'popmart',
    );

    expect(filtered, [pop1, pop2]);
  });
}
