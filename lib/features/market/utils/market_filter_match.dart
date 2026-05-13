import 'package:blindbox_app/models/market_listing.dart';

/// Lightweight browse filters (mock-only, local matching).
bool marketListingMatchesFilter(MarketListing m, String filterId) {
  final c = m.collectible;
  final blob = '${c.name} ${c.series} ${c.brand}'.toLowerCase();
  switch (filterId) {
    case 'all':
      return true;
    case 'pop_mart':
      return c.brand.trim() == 'POP MART';
    case 'hirono':
      return blob.contains('hirono');
    case 'labubu':
      return blob.contains('labubu');
    case 'skullpanda':
      return blob.contains('skullpanda');
    case 'under_100':
      return m.currentPriceUsd < 100;
    case 'rare':
      return m.isRareFind;
    case 'trending':
      return m.isTrending;
    default:
      return true;
  }
}
