import 'package:blindbox_app/features/market/application/collectible_market_diagnostics.dart';
import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Installs live gateway browse rows — eBay title/price/image only (no catalog matching).
///
/// Catalog identity enrichment is skipped here: it scans the full offline catalog
/// on the UI isolate and is nice-to-have for grouping, not required for live browse.
void installLiveBrowseListings(
  List<MarketListing> listings, {
  MarketBrowseQuery? query,
}) {
  final hinted = applyQueryTaxonomyHints(listings, query);
  installMarketBrowseIntelligence(hinted);
  if (kDebugMode) {
    CollectibleMarketDiagnostics.logIfDebug();
  }
}
