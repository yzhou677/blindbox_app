import 'package:blindbox_app/features/market/application/collectible_market_aggregator.dart';
import 'package:blindbox_app/features/market/data/cache/collectible_market_snapshot_cache.dart';
import 'package:blindbox_app/features/market/domain/market_identity_match.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writeMemory readStale round-trip', () {
    final cache = CollectibleMarketSnapshotCache.instance;
    cache.clear();

    const match = MarketIdentityMatch(
      matchedFigureId: 'fig_x',
      matchedSeriesId: 'series_x',
      confidence: MarketMatchConfidence.high,
      score: 0.85,
    );
    final listing = MarketListing(
      id: 'l1',
      providerListingId: 'p1',
      catalogMatch: match,
      collectible: Collectible(
        id: 'l1',
        name: 'Figure',
        series: 'Series',
        brand: 'Brand',
        releaseDate: DateTime.utc(2026),
        imageUrl: '',
      ),
      currentPriceUsd: 20,
      priceChangePercent: 0,
      listingCount: 1,
    );

    final snapshots = buildCollectibleMarketSnapshots([listing]);
    cache.writeMemory(snapshots);

    final stale = cache.readStale();
    expect(stale, isNotNull);
    expect(stale!.single.identity.matchedFigureId, 'fig_x');
    cache.clear();
  });
}
