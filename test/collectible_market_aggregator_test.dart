import 'package:blindbox_app/features/market/application/collectible_market_aggregator.dart';
import 'package:blindbox_app/features/market/domain/aggregation_confidence.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_grouping_tier.dart';
import 'package:blindbox_app/features/market/domain/market_identity_match.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _listing({
  required String id,
  MarketIdentityMatch? match,
  double price = 10,
  String? providerListingId,
}) {
  return MarketListing(
    id: id,
    providerId: 'mock',
    providerListingId: providerListingId ?? id,
    catalogMatch: match,
    collectible: Collectible(
      id: id,
      name: 'Figure $id',
      series: 'Series',
      brand: 'Brand',
      releaseDate: DateTime.utc(2026),
      imageUrl: '',
    ),
    currentPriceUsd: price,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

void main() {
  test('merges medium+ figure matches into one snapshot', () {
    const match = MarketIdentityMatch(
      matchedFigureId: 'fig_a',
      matchedSeriesId: 'series_a',
      matchedBrandId: 'pop_mart',
      matchedIpId: 'the_monsters',
      confidence: MarketMatchConfidence.high,
      score: 0.85,
    );

    final snapshots = buildCollectibleMarketSnapshots([
      _listing(id: 'l1', match: match, price: 40, providerListingId: 'p1'),
      _listing(id: 'l2', match: match, price: 50, providerListingId: 'p2'),
      _listing(id: 'l3', match: match, price: 45, providerListingId: 'p3'),
    ]);

    expect(snapshots.length, 1);
    expect(snapshots.single.listingCount, 3);
    expect(snapshots.single.identity.groupingTier,
        CollectibleMarketGroupingTier.figure);
    expect(snapshots.single.identity.matchedFigureId, 'fig_a');
  });

  test('low confidence does not merge separate listings', () {
    const weak = MarketIdentityMatch(
      matchedBrandId: 'pop_mart',
      confidence: MarketMatchConfidence.low,
      score: 0.4,
    );

    final snapshots = buildCollectibleMarketSnapshots([
      _listing(id: 'a', match: weak, providerListingId: 'a'),
      _listing(id: 'b', match: weak, providerListingId: 'b'),
    ]);

    expect(snapshots.length, 2);
    expect(
      snapshots.every(
        (s) =>
            s.identity.groupingTier ==
            CollectibleMarketGroupingTier.listingFallback,
      ),
      isTrue,
    );
  });

  test('series tier groups when figure id absent', () {
    const seriesMatch = MarketIdentityMatch(
      matchedSeriesId: 'series_macaron',
      matchedBrandId: 'pop_mart',
      matchedIpId: 'the_monsters',
      confidence: MarketMatchConfidence.medium,
      score: 0.6,
    );

    final snapshots = buildCollectibleMarketSnapshots([
      _listing(id: 's1', match: seriesMatch, providerListingId: 's1'),
      _listing(id: 's2', match: seriesMatch, providerListingId: 's2'),
    ]);

    expect(snapshots.length, 1);
    expect(snapshots.single.identity.groupingTier,
        CollectibleMarketGroupingTier.series);
    expect(snapshots.single.aggregationConfidence,
        AggregationConfidence.medium);
  });

  test('dedupes same provider listing id', () {
    const match = MarketIdentityMatch(
      matchedFigureId: 'fig_a',
      matchedSeriesId: 'series_a',
      confidence: MarketMatchConfidence.exact,
      score: 1,
    );

    final snapshots = buildCollectibleMarketSnapshots([
      _listing(id: 'l1', match: match, providerListingId: 'dup'),
      _listing(id: 'l2', match: match, providerListingId: 'dup'),
    ]);

    expect(snapshots.single.listingCount, 1);
  });
}
