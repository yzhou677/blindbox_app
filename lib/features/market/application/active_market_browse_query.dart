import 'package:blindbox_app/features/market/application/market_feed_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the single gateway/offline browse query from feed + search ownership.
///
/// Search overlay with an empty/uncommitted field keeps the **feed** query active
/// so opening Search does not refetch or disturb tab filters.
MarketBrowseQuery resolveActiveMarketBrowseQuery({
  required MarketFeedBrowseState feed,
  required MarketSearchBrowseState search,
  required bool searchOverlayOpen,
}) {
  if (searchOverlayOpen && search.isCommitted) {
    return MarketBrowseQuery(
      brandId: MarketTaxonomyIds.anyBrand,
      ipId: MarketTaxonomyIds.anyIp,
      searchText: search.query.trim(),
      limit: MarketGatewayConfig.initialPageSize,
    );
  }

  return MarketBrowseQuery(
    brandId: feed.brandId,
    ipId: feed.ipId,
    searchText: '',
    limit: MarketGatewayConfig.initialPageSize,
  );
}

final activeMarketBrowseQueryProvider = Provider<MarketBrowseQuery>((ref) {
  final feed = ref.watch(marketFeedBrowseNotifierProvider);
  final search = ref.watch(marketSearchBrowseNotifierProvider);
  final overlayOpen = ref.watch(marketSearchOverlayOpenProvider);
  return resolveActiveMarketBrowseQuery(
    feed: feed,
    search: search,
    searchOverlayOpen: overlayOpen,
  );
});

/// Offline snapshot filter facets — mirrors [activeMarketBrowseQueryProvider].
({String brandId, String ipId, String searchText})
    activeMarketBrowseVisibleFilterFacets(MarketBrowseQuery query) {
  return (
    brandId: query.brandId,
    ipId: query.ipId,
    searchText: query.searchText.trim(),
  );
}

String collectibleMarketBrowseSignatureFromQuery(MarketBrowseQuery query) {
  return query.signature;
}
