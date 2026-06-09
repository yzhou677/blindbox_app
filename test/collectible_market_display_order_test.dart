import 'package:blindbox_app/features/market/application/collectible_market_aggregator.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
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

List<CollectibleMarketSnapshot> _snapshotsForPrices(
  Map<String, double> idToPrice,
) {
  final listings = [
    for (final entry in idToPrice.entries) _listing(entry.key, price: entry.value),
  ];
  MarketBrowseListingsSession.instance.install(listings);
  return buildCollectibleMarketSnapshots(listings, preserveFeedOrder: true);
}

double _repPrice(CollectibleMarketSnapshot snapshot) {
  return MarketBrowseListingsSession.instance
          .findById(snapshot.representativeListingId)
          ?.currentPriceUsd ??
      0;
}

List<double> _repPrices(List<CollectibleMarketSnapshot> snapshots) {
  return snapshots.map(_repPrice).toList();
}

void main() {
  setUp(() {
    MarketBrowseListingsSession.instance.reset();
  });

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

  test('relevance mode appends load-more at bottom without re-sorting', () {
    const signature = 'sig';
    final first = _snapshotsForPrices({'a': 30, 'b': 10});
    final initial = resolveCollectibleMarketDisplaySnapshots(
      snapshots: first,
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: false,
      previousOrderIds: const [],
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: null,
    );
    expect(initial.orderIds, ['listing:a', 'listing:b']);

    final withMore = resolveCollectibleMarketDisplaySnapshots(
      snapshots: _snapshotsForPrices({'a': 30, 'b': 10, 'c': 5}),
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: false,
      previousOrderIds: initial.orderIds,
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: signature,
    );

    expect(
      withMore.snapshots.map((s) => s.identity.snapshotId),
      ['listing:a', 'listing:b', 'listing:c'],
    );
  });

  test('Price ↓ globally re-sorts after load-more', () {
    const signature = 'sig';
    final pageOne = _snapshotsForPrices({'a': 239, 'b': 29, 'c': 15});
    final initial = resolveCollectibleMarketDisplaySnapshots(
      snapshots: pageOne,
      browseSignature: signature,
      priceSort: MarketPriceSort.highToLow,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: const [],
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: null,
    );

    expect(_repPrices(initial.snapshots), [239, 29, 15]);

    final merged = _snapshotsForPrices({
      'a': 239,
      'b': 29,
      'c': 15,
      'd': 200,
      'e': 130,
      'f': 300,
    });
    final afterLoadMore = resolveCollectibleMarketDisplaySnapshots(
      snapshots: merged,
      browseSignature: signature,
      priceSort: MarketPriceSort.highToLow,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: initial.orderIds,
      previousPriceSort: MarketPriceSort.highToLow,
      previousBrowseSignature: signature,
    );

    expect(_repPrices(afterLoadMore.snapshots), [300, 239, 200, 130, 29, 15]);
  });

  test('Price ↑ globally re-sorts after load-more', () {
    const signature = 'sig';
    final pageOne = _snapshotsForPrices({'a': 15, 'b': 29, 'c': 239});
    final initial = resolveCollectibleMarketDisplaySnapshots(
      snapshots: pageOne,
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: const [],
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: null,
    );

    expect(_repPrices(initial.snapshots), [15, 29, 239]);

    final merged = _snapshotsForPrices({
      'a': 15,
      'b': 29,
      'c': 239,
      'd': 10,
      'e': 130,
      'f': 200,
    });
    final afterLoadMore = resolveCollectibleMarketDisplaySnapshots(
      snapshots: merged,
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: initial.orderIds,
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: signature,
    );

    expect(_repPrices(afterLoadMore.snapshots), [10, 15, 29, 130, 200, 239]);
  });

  test('search relevance mode preserves gateway order across load-more pages', () {
    const signature = 'any_brand|any_ip|labubu|relevance';
    final pageOne = _snapshotsForPrices({'a': 239, 'b': 29, 'c': 15});
    final initial = resolveCollectibleMarketDisplaySnapshots(
      snapshots: pageOne,
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: false,
      previousOrderIds: const [],
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: null,
    );

    expect(
      initial.snapshots.map((s) => s.identity.snapshotId),
      ['listing:a', 'listing:b', 'listing:c'],
    );
    expect(_repPrices(initial.snapshots), [239, 29, 15]);

    final merged = _snapshotsForPrices({
      'a': 239,
      'b': 29,
      'c': 15,
      'd': 200,
      'e': 130,
      'f': 300,
    });
    final afterLoadMore = resolveCollectibleMarketDisplaySnapshots(
      snapshots: merged,
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: false,
      previousOrderIds: initial.orderIds,
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: signature,
    );

    expect(
      afterLoadMore.snapshots.map((s) => s.identity.snapshotId),
      [
        'listing:a',
        'listing:b',
        'listing:c',
        'listing:d',
        'listing:e',
        'listing:f',
      ],
    );
    expect(_repPrices(afterLoadMore.snapshots), [239, 29, 15, 200, 130, 300]);
  });

  test('displayOrderCacheNeedsUpdate compares order ids by value', () {
    const signature = 'sig';
    final first = resolveCollectibleMarketDisplaySnapshots(
      snapshots: _snapshotsForPrices({'a': 30, 'b': 10}),
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: const [],
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: null,
    );
    final second = resolveCollectibleMarketDisplaySnapshots(
      snapshots: _snapshotsForPrices({'a': 30, 'b': 10}),
      browseSignature: signature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: first.orderIds,
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: signature,
    );

    expect(first.orderIds, isNot(same(second.orderIds)));
    expect(
      displayOrderCacheNeedsUpdate(
        orderIds: second.orderIds,
        previousOrderIds: first.orderIds,
        priceSort: MarketPriceSort.lowToHigh,
        previousPriceSort: MarketPriceSort.lowToHigh,
        browseSignature: signature,
        previousBrowseSignature: signature,
      ),
      isFalse,
    );
    expect(
      displayOrderCacheNeedsUpdate(
        orderIds: second.orderIds,
        previousOrderIds: const [],
        priceSort: MarketPriceSort.lowToHigh,
        previousPriceSort: MarketPriceSort.lowToHigh,
        browseSignature: signature,
        previousBrowseSignature: signature,
      ),
      isTrue,
    );
  });

  test('search with sortByPrice true would re-sort load-more (market feed only)', () {
    const signature = 'any_brand|any_ip|labubu|relevance';
    final pageOne = _snapshotsForPrices({'a': 239, 'b': 29, 'c': 15});
    final initial = resolveCollectibleMarketDisplaySnapshots(
      snapshots: pageOne,
      browseSignature: signature,
      priceSort: MarketPriceSort.highToLow,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: const [],
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: null,
    );

    final merged = _snapshotsForPrices({
      'a': 239,
      'b': 29,
      'c': 15,
      'd': 200,
      'e': 130,
      'f': 300,
    });
    final afterLoadMore = resolveCollectibleMarketDisplaySnapshots(
      snapshots: merged,
      browseSignature: signature,
      priceSort: MarketPriceSort.highToLow,
      stablePagination: true,
      sortByPrice: true,
      previousOrderIds: initial.orderIds,
      previousPriceSort: MarketPriceSort.highToLow,
      previousBrowseSignature: signature,
    );

    expect(_repPrices(afterLoadMore.snapshots), [300, 239, 200, 130, 29, 15]);
  });
}
