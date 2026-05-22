import 'package:blindbox_app/features/collection/presentation/collection_shelf_series_filter.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shelfSeriesVisibleForBrandFilter returns all for anyBrand', () {
    final rows = [
      testShelfSeries(catalogTemplateId: 'a'),
      testShelfSeries(id: 'b', catalogTemplateId: 'b'),
    ];
    expect(
      shelfSeriesVisibleForBrandFilter(rows, MarketTaxonomyIds.anyBrand),
      rows,
    );
  });

  test('filters by taxonomyBrandId', () {
    final pop = testShelfSeries(catalogTemplateId: 'p');
    final other = testShelfSeries(
      id: 'other',
      catalogTemplateId: 'o',
      taxonomyBrandId: 'tntspace',
    );
    final filtered = shelfSeriesVisibleForBrandFilter(
      [pop, other],
      'pop_mart',
    );
    expect(filtered, [pop]);
  });
}
