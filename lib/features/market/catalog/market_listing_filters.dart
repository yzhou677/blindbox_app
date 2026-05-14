import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Composes taxonomy rails with free-text search (IP, series, names, taxonomy labels).
bool marketListingVisible(
  MarketListing m, {
  required String brandId,
  required String ipId,
  required String queryLower,
}) {
  if (!MarketTaxonomy.listingMatchesFilters(m, brandId: brandId, ipId: ipId)) {
    return false;
  }
  return marketListingMatchesFreeText(m, queryLower);
}

/// Case-insensitive match across collectible fields + taxonomy display keys.
bool marketListingMatchesFreeText(MarketListing m, String queryLower) {
  if (queryLower.isEmpty) return true;

  final c = m.collectible;
  final ipLine = c.ipLine?.trim();
  final brandTaxon =
      m.taxonomyBrandId != null ? MarketTaxonomy.brandById(m.taxonomyBrandId!) : null;
  final ipTaxon =
      m.taxonomyIpId != null ? MarketTaxonomy.ipById(m.taxonomyIpId!) : null;

  final parts = <String>[
    c.name,
    c.series,
    c.brand,
    if (ipLine != null && ipLine.isNotEmpty) ipLine,
    if (brandTaxon != null) brandTaxon.displayLabel,
    if (ipTaxon != null) ipTaxon.displayLabel,
    if (m.taxonomyBrandId != null) m.taxonomyBrandId!.replaceAll('_', ' '),
    if (m.taxonomyIpId != null) m.taxonomyIpId!.replaceAll('_', ' '),
  ];

  final haystack = parts.join(' ').toLowerCase();
  return haystack.contains(queryLower);
}
