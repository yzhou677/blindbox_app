import 'package:blindbox_app/features/market/application/market_identity_matcher.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Attaches [MarketListing.catalogMatch] using the installed catalog identity index.
MarketListing enrichListingIdentity(
  MarketListing listing, {
  MarketIdentityMatcher? matcher,
}) {
  final index = MarketCatalogIdentityCache.current;
  if (index == null) return listing;

  final m = matcher ?? MarketIdentityMatcher(index);
  final match = m.match(
    listing.collectible.name,
    hintBrandId: listing.taxonomyBrandId,
    hintIpId: listing.taxonomyIpId,
  );

  String? brandId = listing.taxonomyBrandId;
  String? ipId = listing.taxonomyIpId;
  if (match.confidence.usableForTaxonomyFilters) {
    brandId = match.matchedBrandId ?? brandId;
    ipId = match.matchedIpId ?? ipId;
  }

  return MarketListing(
    id: listing.id,
    collectible: listing.collectible,
    providerId: listing.providerId,
    providerListingId: listing.providerListingId,
    externalListingUrl: listing.externalListingUrl,
    taxonomyBrandId: brandId,
    taxonomyIpId: ipId,
    currentPriceUsd: listing.currentPriceUsd,
    priceChangePercent: listing.priceChangePercent,
    listingCount: listing.listingCount,
    isTrending: listing.isTrending,
    watchingCount: listing.watchingCount,
    hasSecretFigure: listing.hasSecretFigure,
    isHardToFind: listing.isHardToFind,
    catalogMatch: match.confidence == MarketMatchConfidence.none ? null : match,
  );
}

List<MarketListing> enrichBrowseListingsIdentity(List<MarketListing> listings) {
  final index = MarketCatalogIdentityCache.current;
  if (index == null) return listings;

  final matcher = MarketIdentityMatcher(index);
  return [
    for (final row in listings) enrichListingIdentity(row, matcher: matcher),
  ];
}
