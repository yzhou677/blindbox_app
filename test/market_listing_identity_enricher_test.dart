import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'support/market_identity_test_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MarketCatalogIdentityCache.install(marketIdentityTestBundle());
  });

  tearDown(MarketCatalogIdentityCache.clear);

  test('enrich attaches catalogMatch and taxonomy ids', () {
    final listing = MarketListing(
      id: 'm1',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'the_monsters',
      collectible: Collectible(
        id: 'm1',
        name: 'Labubu Secret Pink',
        series: 'Exciting Macaron',
        brand: 'POP MART',
        releaseDate: DateTime.utc(2026),
        imageUrl: '',
      ),
      currentPriceUsd: 80,
      priceChangePercent: 0,
      listingCount: 3,
    );

    final enriched = enrichListingIdentity(listing);
    expect(enriched.catalogMatch, isNotNull);
    expect(enriched.catalogMatch!.matchedFigureId, 'fig_labubu_secret_pink');
    expect(enriched.taxonomyBrandId, 'pop_mart');
    expect(enriched.taxonomyIpId, 'the_monsters');
  });

  test('without index cache returns listing unchanged', () {
    MarketCatalogIdentityCache.clear();
    final listing = MarketListing(
      id: 'm2',
      collectible: Collectible(
        id: 'm2',
        name: 'Labubu',
        series: 'S',
        brand: 'B',
        releaseDate: DateTime.utc(2026),
        imageUrl: '',
      ),
      currentPriceUsd: 1,
      priceChangePercent: 0,
      listingCount: 1,
    );
    expect(enrichListingIdentity(listing).catalogMatch, isNull);
  });
}
