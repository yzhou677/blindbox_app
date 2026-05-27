import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late MarketProviderBrowseCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = MarketProviderBrowseCache.instance;
    cache.clear(MarketProviderId.mercari);
    cache.clearAllQueryMemory();
  });

  test('readStale returns memory batch', () {
    cache.writeMemory(
      id: MarketProviderId.mercari,
      listings: [_row('cached-1')],
    );

    final stale = cache.readStale(MarketProviderId.mercari);
    expect(stale, isNotNull);
    expect(stale!.single.id, 'cached-1');
  });

  // ---------------------------------------------------------------------------
  // Bounded query cache eviction
  // ---------------------------------------------------------------------------

  group('query cache eviction', () {
    test('read after write returns correct listings', () {
      final listings = [_row('q-row-1')];
      cache.writeForQuery(
        id: MarketProviderId.mercari,
        signature: 'sig_a',
        listings: listings,
      );
      // In-memory read — no async needed.
      final result = cache.readStaleForQuery(
        MarketProviderId.mercari,
        'sig_a',
      );
      expect(result, isNotNull);
      expect(result!.single.id, 'q-row-1');
    });

    test('evicts oldest in-memory entry when capacity is exceeded', () async {
      // Fill to capacity + 1 to trigger eviction.
      // Max is 10; the first entry ('sig_0') should be evicted.
      for (var i = 0; i <= 10; i++) {
        await cache.writeForQuery(
          id: MarketProviderId.mercari,
          signature: 'sig_$i',
          listings: [_row('row_$i')],
        );
      }

      // Entry 0 (oldest) should be gone.
      expect(
        cache.readStaleForQuery(MarketProviderId.mercari, 'sig_0'),
        isNull,
        reason: 'oldest entry should have been evicted at capacity',
      );

      // Entry 10 (newest) should still be present.
      expect(
        cache.readStaleForQuery(MarketProviderId.mercari, 'sig_10'),
        isNotNull,
      );
    });

    test('overwriting existing key does not evict anything', () async {
      // Add 10 distinct entries (at capacity).
      for (var i = 0; i < 10; i++) {
        await cache.writeForQuery(
          id: MarketProviderId.mercari,
          signature: 'sig_$i',
          listings: [_row('row_$i')],
        );
      }

      // Overwrite sig_0 — should not evict any other entry.
      await cache.writeForQuery(
        id: MarketProviderId.mercari,
        signature: 'sig_0',
        listings: [_row('row_0_updated')],
      );

      // All 10 entries should still be present.
      for (var i = 1; i < 10; i++) {
        expect(
          cache.readStaleForQuery(MarketProviderId.mercari, 'sig_$i'),
          isNotNull,
          reason: 'sig_$i should not have been evicted on overwrite',
        );
      }
    });

    test('clearQuery removes entry from memory', () async {
      await cache.writeForQuery(
        id: MarketProviderId.mercari,
        signature: 'sig_clear',
        listings: [_row('r1')],
      );

      cache.clearQuery(MarketProviderId.mercari, 'sig_clear');

      expect(
        cache.readStaleForQuery(MarketProviderId.mercari, 'sig_clear'),
        isNull,
      );
    });
  });
}
