import 'package:blindbox_app/features/market/application/collectible_market_aggregator.dart';
import 'package:blindbox_app/features/market/catalog/collectible_market_filters.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/domain/market_identity_match.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    MarketBrowseListingsSession.instance.reset();
  });

  test('taxonomy filter uses snapshot identity', () {
    final listings = [
      MarketListing(
        id: 'm1',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'the_monsters',
        catalogMatch: const MarketIdentityMatch(
          matchedFigureId: 'fig_a',
          matchedSeriesId: 'series_a',
          matchedBrandId: 'pop_mart',
          matchedIpId: 'the_monsters',
          confidence: MarketMatchConfidence.high,
          score: 0.85,
        ),
        collectible: Collectible(
          id: 'm1',
          name: 'Labubu',
          series: 'Macaron',
          brand: 'POP MART',
          releaseDate: DateTime.utc(2026),
          imageUrl: '',
        ),
        currentPriceUsd: 10,
        priceChangePercent: 0,
        listingCount: 1,
      ),
    ];
    MarketBrowseListingsSession.instance.install(listings);
    final snapshot = buildCollectibleMarketSnapshots(listings).single;

    expect(
      collectibleMarketSnapshotVisible(
        snapshot,
        brandId: 'pop_mart',
        ipId: MarketTaxonomyIds.anyIp,
        searchText: '',
      ),
      isTrue,
    );
    expect(
      collectibleMarketSnapshotVisible(
        snapshot,
        brandId: 'other_brand',
        ipId: MarketTaxonomyIds.anyIp,
        searchText: '',
      ),
      isFalse,
    );
  });
}
