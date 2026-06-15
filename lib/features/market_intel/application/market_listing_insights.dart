import 'package:blindbox_app/models/market_listing.dart';

/// Route path for [MarketInsightsScreen].
const String kMarketInsightsRoutePath = '/market/insights';

/// Builds the Market Insights route with required query parameters.
String marketInsightsRoute({
  required String figureId,
  required String listingId,
}) {
  return Uri(
    path: kMarketInsightsRoutePath,
    queryParameters: {
      'figureId': figureId.trim(),
      'listingId': listingId.trim(),
    },
  ).toString();
}

/// Catalog figure id used to load sold-data [MarketSnapshot] for a listing.
///
/// Returns null when the listing has no figure-level catalog match.
String? marketListingInsightsFigureId(MarketListing listing) {
  final id = listing.catalogMatch?.matchedFigureId?.trim();
  if (id == null || id.isEmpty) return null;
  return id;
}
