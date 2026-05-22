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
      name: 'Test',
      series: '',
      brand: '',
      releaseDate: DateTime.utc(2026),
      imageUrl: '',
    ),
    currentPriceUsd: 10,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

void main() {
  test('readStale returns memory batch', () {
    final cache = MarketProviderBrowseCache.instance;
    cache.clear(MarketProviderId.mercari);
    cache.writeMemory(
      id: MarketProviderId.mercari,
      listings: [_row('cached-1')],
    );

    final stale = cache.readStale(MarketProviderId.mercari);
    expect(stale, isNotNull);
    expect(stale!.single.id, 'cached-1');
    cache.clear(MarketProviderId.mercari);
  });
}
