import 'package:blindbox_app/features/market/application/market_live_browse_install.dart';
import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Legacy entry — installs cached eBay rows when present, otherwise [sessionRows].
void installGatewayMarketBrowse({
  required List<MarketListing> sessionRows,
}) {
  final ebayBatch =
      MarketProviderBrowseCache.instance.batchFor(MarketProviderId.ebay);
  final liveRows = ebayBatch?.listings ?? sessionRows;
  installLiveBrowseListings(liveRows);
}
