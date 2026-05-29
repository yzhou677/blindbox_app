import 'package:blindbox_app/features/collection/presentation/collection_shelf_series_filter.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart'
    show collectionAnyBrandFilterId;
import 'helpers/collection_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shelfSeriesVisibleForBrandFilter returns all for anyBrand', () {
    final rows = [
      testShelfSeries(catalogTemplateId: 'a'),
      testShelfSeries(id: 'b', catalogTemplateId: 'b'),
    ];
    expect(
      shelfSeriesVisibleForBrandFilter(rows, collectionAnyBrandFilterId),
      rows,
    );
  });

  test('filters by normalized collection brand key', () {
    final pop = testShelfSeries(catalogTemplateId: 'p');
    final other = testShelfSeries(
      id: 'other',
      brand: 'TNT SPACE',
      catalogTemplateId: 'o',
      taxonomyBrandId: 'tntspace',
    );
    final filtered = shelfSeriesVisibleForBrandFilter(
      [pop, other],
      'popmart',
    );
    expect(filtered, [pop]);
  });
}
