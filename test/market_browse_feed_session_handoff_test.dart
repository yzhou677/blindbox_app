import 'package:blindbox_app/features/market/application/collectible_market_aggregator.dart';
import 'package:blindbox_app/features/market/application/market_browse_feed_session_handoff.dart';
import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    MarketBrowseListingsSession.instance.reset();
    CollectibleMarketSession.instance.reset();
  });

  group('shouldHideStaleGatewayFeedRows', () {
    test('hides feed rows during gateway transition after search exits', () {
      expect(
        shouldHideStaleGatewayFeedRows(
          gatewayActive: true,
          sessionTransitioning: true,
          immersive: false,
          activeSearchText: '',
        ),
        isTrue,
      );
    });

    test('keeps immersive search rows visible during transition', () {
      expect(
        shouldHideStaleGatewayFeedRows(
          gatewayActive: true,
          sessionTransitioning: true,
          immersive: true,
          activeSearchText: 'dora',
        ),
        isFalse,
      );
    });

    test('keeps feed rows when transition complete', () {
      expect(
        shouldHideStaleGatewayFeedRows(
          gatewayActive: true,
          sessionTransitioning: false,
          immersive: false,
          activeSearchText: '',
        ),
        isFalse,
      );
    });

    test('offline gateway never hides', () {
      expect(
        shouldHideStaleGatewayFeedRows(
          gatewayActive: false,
          sessionTransitioning: true,
          immersive: false,
          activeSearchText: '',
        ),
        isFalse,
      );
    });
  });

  group('marketBrowseFeedResultsForDisplay', () {
    test('returns empty list instead of stale session rows on feed handoff', () {
      final snapshots = List.generate(
        3,
        (i) => buildCollectibleMarketSnapshots([
          MarketListing(
            id: 'm$i',
            collectible: Collectible(
              id: 'm$i',
              name: 'Dora item $i',
              series: 'S',
              brand: 'B',
              releaseDate: DateTime.utc(2026),
              imageUrl: '',
            ),
            currentPriceUsd: 10,
            priceChangePercent: 0,
            listingCount: 1,
          ),
        ]).single,
      );

      final visible = marketBrowseFeedResultsForDisplay(
        sorted: snapshots,
        sessionTransitioning: true,
        immersive: false,
        activeSearchText: '',
        gatewayActive: true,
      );

      expect(visible, isEmpty);
    });
  });

  group('resetCollectibleMarketSessionForGatewayFeedHandoff', () {
    test('clears collectible session when live gateway is active', () {
      if (!MarketGatewayConfig.isActive) {
        return;
      }

      installMarketBrowseIntelligence([
        MarketListing(
          id: 'mkt-dora',
          collectible: Collectible(
            id: 'mkt-dora',
            name: 'Dora Figure',
            series: 'S',
            brand: 'B',
            releaseDate: DateTime.utc(2026),
            imageUrl: '',
          ),
          currentPriceUsd: 12,
          priceChangePercent: 0,
          listingCount: 1,
        ),
      ]);
      expect(CollectibleMarketSession.instance.list.length, 1);

      resetCollectibleMarketSessionForGatewayFeedHandoff();

      expect(CollectibleMarketSession.instance.isInstalled, isFalse);
    });
  });
}
