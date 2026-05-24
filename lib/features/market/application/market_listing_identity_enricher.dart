import 'package:blindbox_app/features/market/application/market_identity_matcher.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_resolver.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Applies chip/query taxonomy hints before catalog + title enrichment.
List<MarketListing> applyQueryTaxonomyHints(
  List<MarketListing> listings, [
  MarketBrowseQuery? query,
]) {
  if (query == null) return listings;
  final brandHint = query.brandId != MarketTaxonomyIds.anyBrand
      ? query.brandId
      : null;
  final ipHint =
      query.ipId != MarketTaxonomyIds.anyIp ? query.ipId : null;
  if (brandHint == null && ipHint == null) return listings;

  return [
    for (final row in listings)
      MarketListing(
        id: row.id,
        collectible: row.collectible,
        providerId: row.providerId,
        providerListingId: row.providerListingId,
        externalListingUrl: row.externalListingUrl,
        taxonomyBrandId: brandHint ?? row.taxonomyBrandId,
        taxonomyIpId: ipHint ?? row.taxonomyIpId,
        currentPriceUsd: row.currentPriceUsd,
        priceChangePercent: row.priceChangePercent,
        listingCount: row.listingCount,
        isTrending: row.isTrending,
        watchingCount: row.watchingCount,
        hasSecretFigure: row.hasSecretFigure,
        isHardToFind: row.isHardToFind,
        catalogMatch: row.catalogMatch,
      ),
  ];
}

/// Attaches [MarketListing.catalogMatch] using the installed catalog identity index.
MarketListing enrichListingIdentity(
  MarketListing listing, {
  MarketIdentityMatcher? matcher,
}) {
  final index = MarketCatalogIdentityCache.current;
  var working = listing;

  if (index == null) {
    return _enrichTaxonomyFromTitleOnly(working);
  }

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
  } else {
    final taxonomy = const TitleTaxonomyResolver().resolve(listing.collectible.name);
    if (taxonomy.brandId != null &&
        taxonomy.confidence >= TitleTaxonomyResolver.minConfidenceForBrandOnly) {
      brandId ??= taxonomy.brandId;
      ipId ??= taxonomy.ipId;
    }
  }

  working = MarketListing(
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
  return working;
}

MarketListing _enrichTaxonomyFromTitleOnly(MarketListing listing) {
  final taxonomy = const TitleTaxonomyResolver().resolve(listing.collectible.name);
  if (taxonomy.brandId == null) return listing;
  return MarketListing(
    id: listing.id,
    collectible: listing.collectible,
    providerId: listing.providerId,
    providerListingId: listing.providerListingId,
    externalListingUrl: listing.externalListingUrl,
    taxonomyBrandId: listing.taxonomyBrandId ?? taxonomy.brandId,
    taxonomyIpId: listing.taxonomyIpId ?? taxonomy.ipId,
    currentPriceUsd: listing.currentPriceUsd,
    priceChangePercent: listing.priceChangePercent,
    listingCount: listing.listingCount,
    isTrending: listing.isTrending,
    watchingCount: listing.watchingCount,
    hasSecretFigure: listing.hasSecretFigure,
    isHardToFind: listing.isHardToFind,
    catalogMatch: listing.catalogMatch,
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
