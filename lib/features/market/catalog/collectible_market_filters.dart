import 'package:blindbox_app/features/market/application/collectible_market_display_resolver.dart';
import 'package:blindbox_app/features/market/catalog/market_listing_filters.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/domain/aggregation_confidence.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
bool collectibleMarketSnapshotVisible(
  CollectibleMarketSnapshot snapshot, {
  required String brandId,
  required String ipId,
  required String queryLower,
}) {
  if (!_snapshotMatchesTaxonomy(snapshot, brandId: brandId, ipId: ipId)) {
    return false;
  }
  if (queryLower.isEmpty) return true;

  final display = resolveCollectibleMarketDisplay(snapshot);
  final displayHaystack =
      '${display.title} ${display.subtitle}'.toLowerCase();
  if (displayHaystack.contains(queryLower)) return true;

  for (final id in snapshot.listingIds) {
    final listing = MarketBrowseListingsSession.instance.findById(id);
    if (listing != null &&
        marketListingMatchesFreeText(listing, queryLower)) {
      return true;
    }
  }
  return false;
}

bool _snapshotMatchesTaxonomy(
  CollectibleMarketSnapshot snapshot, {
  required String brandId,
  required String ipId,
}) {
  if (brandId == MarketTaxonomyIds.anyBrand &&
      ipId == MarketTaxonomyIds.anyIp) {
    return true;
  }

  final identity = snapshot.identity;
  final conf = snapshot.aggregationConfidence;
  if (conf.rank < AggregationConfidence.low.rank) {
    for (final id in snapshot.listingIds) {
      final listing = MarketBrowseListingsSession.instance.findById(id);
      if (listing != null &&
          MarketTaxonomy.listingMatchesFilters(
            listing,
            brandId: brandId,
            ipId: ipId,
          )) {
        return true;
      }
    }
    return brandId == MarketTaxonomyIds.anyBrand &&
        ipId == MarketTaxonomyIds.anyIp;
  }

  if (brandId != MarketTaxonomyIds.anyBrand &&
      identity.matchedBrandId != brandId) {
    return false;
  }
  if (ipId != MarketTaxonomyIds.anyIp && identity.matchedIpId != ipId) {
    return false;
  }
  return true;
}

bool snapshotUsableForTaxonomyFilters(CollectibleMarketSnapshot snapshot) {
  return snapshot.aggregationConfidence.rank >= AggregationConfidence.low.rank;
}
