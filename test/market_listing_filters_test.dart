import 'package:blindbox_app/features/market/catalog/market_listing_filters.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/mock_market_listings.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/features/market/data/source/asset_market_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    MarketBrowseListingsSession.instance.reset();
    final repo = MarketListingsRepository([AssetMarketSource()]);
    MarketBrowseListingsSession.instance.install(await repo.loadBrowseListings());
  });

  tearDown(() {
    MarketBrowseListingsSession.instance.reset();
  });

  test('hirono matches taxonomy IP and display copy', () {
    final m = mockMarketListings.firstWhere((e) => e.id == 'mkt-hirono-wander');
    expect(
      marketListingVisible(
        m,
        brandId: MarketTaxonomyIds.anyBrand,
        ipId: MarketTaxonomyIds.anyIp,
        searchText: 'hirono',
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
        searchText: 'nommi',
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
