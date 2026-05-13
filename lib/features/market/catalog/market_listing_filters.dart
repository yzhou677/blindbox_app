import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Composes taxonomy rails with free-text search (figures / series / display brand).
bool marketListingVisible(
  MarketListing m, {
  required String brandId,
  required String ipId,
  required String queryLower,
}) {
  if (!MarketTaxonomy.listingMatchesFilters(m, brandId: brandId, ipId: ipId)) {
    return false;
  }
  if (queryLower.isEmpty) return true;
  final c = m.collectible;
  return c.name.toLowerCase().contains(queryLower) ||
      c.series.toLowerCase().contains(queryLower) ||
      c.brand.toLowerCase().contains(queryLower);
}
