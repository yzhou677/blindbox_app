import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _row(String id) {
  return MarketListing(
    id: id,
    providerId: MarketProviderId.mercari.wireName,
    providerListingId: id,
    collectible: Collectible(
      id: id,
      name: id,
      series: '',
      brand: '',
      releaseDate: DateTime.utc(2026),
      imageUrl: '',
    ),
    currentPriceUsd: 1,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

void main() {
  test('append dedupes provider listings', () async {
    final cache = MarketProviderBrowseCache.instance;
    cache.clear(MarketProviderId.mercari);

    await cache.write(
      id: MarketProviderId.mercari,
      listings: [_row('a')],
      hasMore: true,
      nextCursor: 'c2',
    );
    await cache.append(
      id: MarketProviderId.mercari,
      newListings: [_row('a'), _row('b')],
      nextCursor: 'c3',
      hasMore: false,
    );

    final batch = cache.batchFor(MarketProviderId.mercari);
    expect(batch?.listings.length, 2);
    expect(batch?.nextCursor, 'c3');
    expect(batch?.hasMore, isFalse);
  });
}
