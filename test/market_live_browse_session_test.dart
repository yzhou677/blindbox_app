import 'package:blindbox_app/features/market/application/market_live_browse_session.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _row(String id) {
  return MarketListing(
    id: id,
    providerId: 'ebay',
    providerListingId: id,
    collectible: Collectible(
      id: id,
      name: 'Test $id',
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

void main() {  test('resetForQuery bumps generation and hydrates stale rows', () {
    final session = MarketLiveBrowseSession();
    const query = MarketBrowseQuery(brandId: 'pop_mart');

    final gen = session.resetForQuery(query, staleListings: const []);
    expect(gen, 1);
    expect(session.state.generation, 1);
    expect(session.state.querySignature, query.signature);
    expect(session.state.isLoadingInitial, false);
  });

  test('stale generation responses are ignored', () {
    final session = MarketLiveBrowseSession();
    const query = MarketBrowseQuery(brandId: 'pop_mart');
    session.resetForQuery(query);
    final gen = session.state.generation;

    session.applyFirstPage(
      generation: gen - 1,
      listings: const [],
      hasMore: false,
    );
    expect(session.state.listings, isEmpty);

    session.applyFirstPage(
      generation: gen,
      listings: const [],
      hasMore: true,
      nextCursor: 'next',
    );
    expect(session.state.hasMore, true);
    expect(session.state.nextCursor, 'next');
  });

  test('applyNextPage appends merged listings and clears load-more', () {
    final session = MarketLiveBrowseSession();
    const query = MarketBrowseQuery(brandId: 'pop_mart');
    session.resetForQuery(query);
    final gen = session.state.generation;

    session.applyFirstPage(
      generation: gen,
      listings: [_row('a')],
      hasMore: true,
      nextCursor: 'page2',
    );

    session.markLoadingMore(generation: gen);
    session.applyNextPage(
      generation: gen,
      listings: [_row('a'), _row('b')],
      hasMore: false,
    );

    expect(session.state.listings.length, 2);
    expect(session.state.isLoadingMore, false);
    expect(session.state.hasMore, false);
  });

  test('hydrateStaleListings ignores stale generation', () {
    final session = MarketLiveBrowseSession();
    const query = MarketBrowseQuery(brandId: 'pop_mart', ipId: 'molly');
    final gen = session.resetForQuery(query);
    session.markLoadingInitial(generation: gen);

    session.resetForQuery(
      const MarketBrowseQuery(brandId: 'pop_mart', ipId: 'skullpanda'),
    );
    session.hydrateStaleListings(
      generation: gen,
      listings: [_row('stale')],
    );
    expect(session.state.listings, isEmpty);
  });

  test('hydrateStaleListings updates rows for active generation', () {
    final session = MarketLiveBrowseSession();
    const query = MarketBrowseQuery(brandId: 'pop_mart', ipId: 'molly');
    final gen = session.resetForQuery(query);
    session.markLoadingInitial(generation: gen);

    session.hydrateStaleListings(
      generation: gen,
      listings: [_row('cached')],
      staleHasMore: true,
      staleCursor: 'c1',
    );
    expect(session.state.listings, hasLength(1));
    expect(session.state.fromStaleCache, isTrue);
    expect(session.state.isLoadingInitial, isTrue);
    expect(session.state.hasMore, isTrue);
  });
}
