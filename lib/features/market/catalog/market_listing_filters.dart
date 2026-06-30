import 'package:blindbox_app/core/search/search_matcher.dart';
import 'package:blindbox_app/core/search/search_normalizer.dart';
import 'package:blindbox_app/core/search/search_tokenizer.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Composes taxonomy rails with free-text search (IP, series, names, taxonomy labels).
bool marketListingVisible(
  MarketListing m, {
  required String brandId,
  required String ipId,
  required String searchText,
}) {
  if (!MarketTaxonomy.listingMatchesFilters(m, brandId: brandId, ipId: ipId)) {
    return false;
  }
  return marketListingMatchesFreeText(m, searchText);
}

/// Token-AND match across collectible fields + taxonomy display keys (Search V2).
bool marketListingMatchesFreeText(MarketListing m, String rawQuery) {
  final tokens = SearchTokenizer.tokenize(rawQuery);
  if (tokens.isEmpty) return true;
  return SearchMatcher.allTokensMatch(_marketListingHaystack(m), tokens);
}

String _marketListingHaystack(MarketListing m) {
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

  return parts.map(SearchNormalizer.normalizeForMatch).join(' ');
}
