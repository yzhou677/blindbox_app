import 'package:blindbox_app/features/market/application/market_listing_dedupe.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Merges offline asset rows with live gateway rows (deduped by provider id).
List<MarketListing> mergeMarketBrowseListings({
  required List<MarketListing> assetRows,
  List<MarketListing> mercariRows = const [],
  List<MarketListing> liveGatewayRows = const [],
  int maxLiveRows = 72,
}) {
  final seen = <String>{};
  for (final row in assetRows) {
    seen.add(marketListingDedupeKey(row));
  }

  final out = List<MarketListing>.from(assetRows);
  var liveAdded = 0;
  for (final row in [...liveGatewayRows, ...mercariRows]) {
    if (liveAdded >= maxLiveRows) break;
    final key = marketListingDedupeKey(row);
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(row);
    liveAdded++;
  }
  return out;
}

List<MarketListing> assetRowsFromSession(List<MarketListing> session) {
  return session
      .where((e) => e.providerId == MarketProviderId.mock.wireName)
      .toList(growable: false);
}
