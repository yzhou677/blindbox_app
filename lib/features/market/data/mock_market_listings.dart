import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Browse rows installed via [bootstrapMarketBrowseListings] (bundled market JSON → domain).
///
/// Kept for tests and call sites that expect this symbol; data is no longer const here.
List<MarketListing> get mockMarketListings => MarketBrowseListingsSession.instance.list;

MarketListing? mockMarketListingById(String id) {
  return MarketBrowseListingsSession.instance.findById(id);
}

List<MarketListing> mockTrendingMarketListings() {
  return MarketBrowseListingsSession.instance.trending;
}
