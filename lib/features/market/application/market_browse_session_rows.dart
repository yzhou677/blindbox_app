import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/models/market_listing.dart';

List<MarketListing> currentMarketBrowseSessionRows() {
  return MarketBrowseListingsSession.instance.isInstalled
      ? MarketBrowseListingsSession.instance.list
      : const [];
}
