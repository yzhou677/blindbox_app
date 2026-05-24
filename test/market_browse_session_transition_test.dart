import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_session.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/features/market/widgets/market_browse_session_transition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('marketBrowseSessionTransitionActive', () {
    const browseDefault = MarketBrowseState();

    test('is false when UI and live query signatures match and idle', () {
      const live = MarketLiveBrowseState(
        query: MarketBrowseQuery(),
      );
      expect(
        marketBrowseSessionTransitionActive(
          browseDefault,
          live,
          gatewayActive: true,
        ),
        isFalse,
      );
    });

    test('is true when live session is loading initial page', () {
      const live = MarketLiveBrowseState(
        query: MarketBrowseQuery(),
        isLoadingInitial: true,
      );
      expect(
        marketBrowseSessionTransitionActive(
          browseDefault,
          live,
          gatewayActive: true,
        ),
        isTrue,
      );
    });

    test('is true when UI filter changed before live session caught up', () {
      const browse = MarketBrowseState(
        brandId: 'pop_mart',
        ipId: MarketTaxonomyIds.anyIp,
      );
      const live = MarketLiveBrowseState(
        query: MarketBrowseQuery(),
      );
      expect(
        marketBrowseSessionTransitionActive(
          browse,
          live,
          gatewayActive: true,
        ),
        isTrue,
      );
    });

    test('is false during loadMore only', () {
      const browse = MarketBrowseState(
        brandId: 'pop_mart',
      );
      const live = MarketLiveBrowseState(
        query: MarketBrowseQuery(brandId: 'pop_mart'),
        isLoadingMore: true,
      );
      expect(
        marketBrowseSessionTransitionActive(
          browse,
          live,
          gatewayActive: true,
        ),
        isFalse,
      );
    });
  });
}
