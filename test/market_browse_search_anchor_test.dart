import 'package:blindbox_app/features/market/application/market_browse_search_anchor.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anchors generic discover search', () {
    expect(
      MarketBrowseSearchAnchor.shouldAnchorDiscoverSearch(
        'baby',
        MarketTaxonomyIds.anyBrand,
        MarketTaxonomyIds.anyIp,
      ),
      isTrue,
    );
    expect(
      MarketBrowseSearchAnchor.resolveSearchText(
        searchText: 'baby',
        brandId: MarketTaxonomyIds.anyBrand,
        ipId: MarketTaxonomyIds.anyIp,
      ),
      'blind box vinyl figure baby',
    );
  });

  test('does not anchor taxonomy-native IP search', () {
    expect(
      MarketBrowseSearchAnchor.isCollectibleNativeSearch('labubu'),
      isTrue,
    );
    expect(
      MarketBrowseSearchAnchor.shouldAnchorDiscoverSearch(
        'labubu',
        MarketTaxonomyIds.anyBrand,
        MarketTaxonomyIds.anyIp,
      ),
      isFalse,
    );
  });

  test('does not anchor when brand chip provides context', () {
    expect(
      MarketBrowseSearchAnchor.shouldAnchorDiscoverSearch(
        'baby',
        'pop_mart',
        MarketTaxonomyIds.anyIp,
      ),
      isFalse,
    );
  });
}
