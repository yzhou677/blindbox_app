import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_browse_merge.dart';
import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/application/market_match_diagnostics.dart';
import 'package:blindbox_app/features/market/application/collectible_market_diagnostics.dart';
import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/source/ebay_gateway_market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Merges asset session rows with cached eBay gateway rows and installs intelligence.
void installGatewayMarketBrowse({
  required List<MarketListing> sessionRows,
  EbayGatewayMarketSource? ebaySource,
}) {
  final assetBase = assetRowsFromSession(sessionRows);
  final ebayBatch =
      MarketProviderBrowseCache.instance.batchFor(MarketProviderId.ebay);
  final liveRows = ebayBatch?.listings ?? const <MarketListing>[];
  final merged = mergeMarketBrowseListings(
    assetRows: assetBase,
    liveGatewayRows: liveRows,
    maxLiveRows: MarketGatewayConfig.maxLiveRows,
  );
  final enriched = enrichBrowseListingsIdentity(merged);
  installMarketBrowseIntelligence(enriched);
  MarketMatchDiagnostics.logIfDebug(enriched);
  CollectibleMarketDiagnostics.logIfDebug();
}
