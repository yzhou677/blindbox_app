import 'package:blindbox_app/features/market/application/active_market_browse_query.dart';
import 'package:blindbox_app/features/market/application/market_browse_query_composer.dart';
import 'package:blindbox_app/features/market/application/market_feed_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketSearchBrowseNotifier', () {
    test('commitQuery activates committed search', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(marketSearchBrowseNotifierProvider.notifier);

      n.commitQuery('lab');
      final s = container.read(marketSearchBrowseNotifierProvider);
      expect(s.query, 'lab');
      expect(s.isCommitted, true);
    });

    test('clearing query exits committed search mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(marketSearchBrowseNotifierProvider.notifier);

      n.commitQuery('x');
      expect(
        container.read(marketSearchBrowseNotifierProvider).isCommitted,
        true,
      );

      n.commitQuery('');
      final s = container.read(marketSearchBrowseNotifierProvider);
      expect(s.query, '');
      expect(s.isCommitted, false);
    });

    test('clearSession clears query and exits search mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(marketSearchBrowseNotifierProvider.notifier);

      n.commitQuery('labubu');
      expect(
        container.read(marketSearchBrowseNotifierProvider).isCommitted,
        true,
      );

      n.clearSession();
      final s = container.read(marketSearchBrowseNotifierProvider);
      expect(s.query, '');
      expect(s.isCommitted, false);
    });

    test('beginOverlay resets to clean search context', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(marketSearchBrowseNotifierProvider.notifier);

      n.commitQuery('labubu');
      n.beginOverlay();
      final s = container.read(marketSearchBrowseNotifierProvider);
      expect(s.query, '');
      expect(s.isCommitted, false);
    });
  });

  group('MarketFeedBrowseNotifier', () {
    test('isMarketBrowseRootPath matches market tab root only', () {
      expect(isMarketBrowseRootPath('/market'), isTrue);
      expect(isMarketBrowseRootPath('/market/search'), isFalse);
      expect(isMarketBrowseRootPath('/market/listing/abc'), isFalse);
    });

    test('selecting Any Brand clears a hidden IP filter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(marketFeedBrowseNotifierProvider.notifier);

      n.setBrand('pop_mart');
      n.setIp('pucky');
      expect(
        container.read(marketFeedBrowseNotifierProvider).ipId,
        'pucky',
      );

      n.setBrand(MarketTaxonomyIds.anyBrand);
      final s = container.read(marketFeedBrowseNotifierProvider);
      expect(s.brandId, MarketTaxonomyIds.anyBrand);
      expect(s.ipId, MarketTaxonomyIds.anyIp);
      expect(s.filtersActive, isFalse);
    });

    test('Any Brand feed query drops prior IP from gateway facets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final feed = container.read(marketFeedBrowseNotifierProvider.notifier);
      final overlay = container.read(marketSearchOverlayOpenProvider.notifier);

      feed.setBrand('pop_mart');
      feed.setIp('pucky');
      overlay.setOpen(false);

      final constrained = container.read(activeMarketBrowseQueryProvider);
      expect(constrained.ipId, 'pucky');
      expect(
        MarketBrowseQueryComposer.composeUpstreamQ(constrained).toLowerCase(),
        contains('pucky'),
      );

      feed.setBrand(MarketTaxonomyIds.anyBrand);
      final reset = container.read(activeMarketBrowseQueryProvider);
      expect(reset.ipId, MarketTaxonomyIds.anyIp);
      expect(reset.signature, 'any_brand|any_ip||relevance');

      final upstream =
          MarketBrowseQueryComposer.composeUpstreamQ(reset).toLowerCase();
      expect(upstream, isNot(contains('pucky')));
    });
  });

  group('activeMarketBrowseQueryProvider', () {
    test('empty search overlay keeps feed query active', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(marketFeedBrowseNotifierProvider.notifier)
        ..setBrand('pop_mart')
        ..setIp('pucky');
      container.read(marketSearchOverlayOpenProvider.notifier).setOpen(true);

      final query = container.read(activeMarketBrowseQueryProvider);
      expect(query.brandId, 'pop_mart');
      expect(query.ipId, 'pucky');
      expect(query.searchText, isEmpty);
    });

    test('committed search upstream q ignores feed IP facet', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(marketFeedBrowseNotifierProvider.notifier)
        ..setBrand('pop_mart')
        ..setIp('pucky');
      container.read(marketSearchOverlayOpenProvider.notifier).setOpen(true);
      container
          .read(marketSearchBrowseNotifierProvider.notifier)
          .commitQuery('nommi');

      final searchQuery = container.read(activeMarketBrowseQueryProvider);
      expect(searchQuery.signature, 'any_brand|any_ip|nommi|relevance');

      final upstream =
          MarketBrowseQueryComposer.composeUpstreamQ(searchQuery).toLowerCase();
      expect(upstream, isNot(contains('pucky')));
      expect(upstream, contains('nommi'));
    });

    test('committed search ignores feed taxonomy while preserving chip state',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final feed = container.read(marketFeedBrowseNotifierProvider.notifier);
      final search = container.read(marketSearchBrowseNotifierProvider.notifier);
      final overlay = container.read(marketSearchOverlayOpenProvider.notifier);

      feed.setBrand('pop_mart');
      feed.setIp('pucky');
      overlay.setOpen(true);
      search.commitQuery('nommi');

      final feedState = container.read(marketFeedBrowseNotifierProvider);
      expect(feedState.brandId, 'pop_mart');
      expect(feedState.ipId, 'pucky');

      final searchState = container.read(marketSearchBrowseNotifierProvider);
      expect(searchState.isCommitted, isTrue);

      final searchQuery = container.read(activeMarketBrowseQueryProvider);
      expect(searchQuery.brandId, MarketTaxonomyIds.anyBrand);
      expect(searchQuery.ipId, MarketTaxonomyIds.anyIp);
      expect(searchQuery.searchText, 'nommi');

      search.clearSession();
      overlay.setOpen(false);

      final afterFeed = container.read(marketFeedBrowseNotifierProvider);
      expect(afterFeed.brandId, 'pop_mart');
      expect(afterFeed.ipId, 'pucky');

      final feedQuery = container.read(activeMarketBrowseQueryProvider);
      expect(feedQuery.brandId, 'pop_mart');
      expect(feedQuery.ipId, 'pucky');
      expect(feedQuery.searchText, isEmpty);
    });
  });
}
