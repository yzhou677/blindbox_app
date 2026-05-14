import 'package:blindbox_app/features/market/catalog/market_listing_filters.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/mock_market_listings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hirono matches taxonomy IP and display copy', () {
    final m = mockMarketListings.firstWhere((e) => e.id == 'mkt-hirono-wander');
    expect(
      marketListingVisible(
        m,
        brandId: MarketTaxonomyIds.anyBrand,
        ipId: MarketTaxonomyIds.anyIp,
        queryLower: 'hirono',
      ),
      true,
    );
  });

  test('slug-style query matches taxonomy id underscores', () {
    final m = mockMarketListings.firstWhere((e) => e.id == 'mkt-nommi-metro');
    expect(
      marketListingVisible(
        m,
        brandId: MarketTaxonomyIds.anyBrand,
        ipId: MarketTaxonomyIds.anyIp,
        queryLower: 'nommi',
      ),
      true,
    );
  });

  test('marketListingMatchesFreeText is false for unrelated query', () {
    final m = mockMarketListings.firstWhere((e) => e.id == 'mkt-luna');
    expect(
      marketListingMatchesFreeText(m, 'zzznope'),
      false,
    );
  });
}
