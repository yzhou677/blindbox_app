import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Merges offline asset rows with live Mercari sandbox rows (deduped by provider id).
List<MarketListing> mergeMarketBrowseListings({
  required List<MarketListing> assetRows,
  required List<MarketListing> mercariRows,
  int maxMercariRows = 24,
}) {
  final seen = <String>{};
  for (final row in assetRows) {
    seen.add(_dedupeKey(row));
  }

  final out = List<MarketListing>.from(assetRows);
  var mercariAdded = 0;
  for (final row in mercariRows) {
    if (mercariAdded >= maxMercariRows) break;
    final key = _dedupeKey(row);
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(row);
    mercariAdded++;
  }
  return out;
}

List<MarketListing> assetRowsFromSession(List<MarketListing> session) {
  return session
      .where((e) => e.providerId == MarketProviderId.mock.wireName)
      .toList(growable: false);
}

String _dedupeKey(MarketListing row) {
  final native = row.providerListingId?.trim();
  if (native != null && native.isNotEmpty) return '${row.providerId}:$native';
  return '${row.providerId}:${row.id}';
}
