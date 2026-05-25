import 'package:blindbox_app/features/market/application/collectible_market_aggregator.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_display_order.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _listing(String id, {double price = 10}) {
  return MarketListing(
    id: id,
    collectible: Collectible(
      id: id,
      name: 'Listing $id',
      series: '',
      brand: '',
      releaseDate: DateTime.utc(2026),
      imageUrl: '',
    ),
    currentPriceUsd: price,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

CollectibleMarketSnapshot _snapshot(String id, {double price = 10}) {
  final listings = [_listing(id, price: price)];
  return buildCollectibleMarketSnapshots(listings, preserveFeedOrder: true).single;
}

void main() {
  test('preserveFeedOrder keeps pagination append order', () {
    final pageOne = buildCollectibleMarketSnapshots(
      [_listing('a', price: 30), _listing('b', price: 10)],
      preserveFeedOrder: true,
    );
    final merged = buildCollectibleMarketSnapshots(
      [
        _listing('a', price: 30),
        _listing('b', price: 10),
        _listing('c', price: 5),
      ],
      preserveFeedOrder: true,
    );

    expect(pageOne.map((s) => s.identity.snapshotId), ['listing:a', 'listing:b']);
    expect(merged.last.identity.snapshotId, 'listing:c');
  });

  test('resolveCollectibleMarketDisplaySnapshots appends load-more at bottom', () {
    final first = [
      _snapshot('a', price: 30),
      _snapshot('b', price: 10),
    ];
    final initial = resolveCollectibleMarketDisplaySnapshots(
      snapshots: first,
      browseSignature: 'sig',
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      previousOrderIds: const [],
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: null,
    );
  expect(initial.orderIds, ['listing:a', 'listing:b']);

    final withMore = resolveCollectibleMarketDisplaySnapshots(
      snapshots: [...first, _snapshot('c', price: 5)],
      browseSignature: 'sig',
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      previousOrderIds: initial.orderIds,
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: 'sig',
    );

    expect(
      withMore.snapshots.map((s) => s.identity.snapshotId),
      ['listing:a', 'listing:b', 'listing:c'],
    );
  });
}
