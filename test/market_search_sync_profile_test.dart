import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _listing(int i) {
  final id = 'listing_$i';
  return MarketListing(
    id: id,
    providerId: 'ebay',
    providerListingId: id,
    collectible: Collectible(
      id: id,
      name: 'Zor test figure $i series blind box',
      series: 'Series',
      brand: 'Brand',
      releaseDate: DateTime.utc(2026),
      imageUrl: 'https://example.com/$i.jpg',
    ),
    currentPriceUsd: 10.0 + i,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

void main() {
  tearDown(() {
    MarketBrowseListingsSession.instance.reset();
    CollectibleMarketSession.instance.reset();
  });

  test('profiles installMarketBrowseIntelligence on UI isolate', () {
    for (final count in [0, 12, 72]) {
      final listings = List.generate(count, _listing);
      final sw = Stopwatch()..start();
      installMarketBrowseIntelligence(listings, preserveFeedOrder: true);
      sw.stop();
      // ignore: avoid_print
      print(
        '[MarketSearchProfile] install count=$count elapsed=${sw.elapsedMilliseconds}ms',
      );
      expect(
        sw.elapsedMilliseconds,
        lessThan(500),
        reason: 'install for $count rows should stay well under ANR budget',
      );
    }
  });
}
