import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubMarketSource implements MarketSource {
  _StubMarketSource({
    required this.providerId,
    required this.listings,
    this.throws = false,
  });

  @override
  final MarketProviderId providerId;
  final List<MarketListing> listings;
  final bool throws;

  @override
  Future<List<MarketListing>> fetchBrowseListings() async {
    if (throws) throw StateError('provider failed');
    return listings;
  }
}

MarketListing _listing(String id) {
  return MarketListing(
    id: id,
    providerId: MarketProviderId.mock.wireName,
    collectible: Collectible(
      id: id,
      name: 'Figure $id',
      series: 'Series',
      brand: 'Brand',
      releaseDate: DateTime.utc(2026),
      imageUrl: '',
    ),
    currentPriceUsd: 10,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

void main() {
  test('merges listings from multiple sources in order', () async {
    final repo = MarketListingsRepository([
      _StubMarketSource(
        providerId: MarketProviderId.mock,
        listings: [_listing('a')],
      ),
      _StubMarketSource(
        providerId: MarketProviderId.ebay,
        listings: [_listing('b')],
      ),
    ]);

    final merged = await repo.loadBrowseListings();
    expect(merged.map((e) => e.id).toList(), ['a', 'b']);
  });

  test('failed source yields empty batch without failing merge', () async {
    final repo = MarketListingsRepository([
      _StubMarketSource(
        providerId: MarketProviderId.mercari,
        listings: [_listing('ok')],
        throws: true,
      ),
      _StubMarketSource(
        providerId: MarketProviderId.mock,
        listings: [_listing('ok')],
      ),
    ]);

    final merged = await repo.loadBrowseListings();
    expect(merged.length, 1);
    expect(merged.single.id, 'ok');
  });

  test('empty sources list returns empty', () async {
    final repo = MarketListingsRepository([]);
    expect(await repo.loadBrowseListings(), isEmpty);
  });
}
