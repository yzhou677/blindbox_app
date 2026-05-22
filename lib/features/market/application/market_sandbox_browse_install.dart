import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_browse_merge.dart';
import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/application/market_match_diagnostics.dart';
import 'package:blindbox_app/features/market/application/collectible_market_diagnostics.dart';
import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/mercari_sandbox_market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Merges asset session rows with cached Mercari rows and installs intelligence.
void installSandboxMarketBrowse({
  required List<MarketListing> sessionRows,
  MercariSandboxMarketSource? mercariSource,
}) {
  final source = mercariSource ?? MercariSandboxMarketSource();
  final assetBase = assetRowsFromSession(sessionRows);
  final mercariBatch =
      MarketProviderBrowseCache.instance.batchFor(MarketProviderId.mercari);
  final mercariRows = mercariBatch?.listings ?? const <MarketListing>[];
  final merged = mergeMarketBrowseListings(
    assetRows: assetBase,
    mercariRows: mercariRows,
    maxMercariRows: MarketSandboxConfig.maxMercariTotalRows,
  );
  final enriched = enrichBrowseListingsIdentity(merged);
  installMarketBrowseIntelligence(enriched);
  MarketMatchDiagnostics.logIfDebug(enriched);
  CollectibleMarketDiagnostics.logIfDebug();
}

List<MarketListing> currentSessionRows() {
  return MarketBrowseListingsSession.instance.isInstalled
      ? MarketBrowseListingsSession.instance.list
      : const [];
}
