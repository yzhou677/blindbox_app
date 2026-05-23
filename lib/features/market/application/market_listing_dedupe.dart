import 'package:blindbox_app/models/market_listing.dart';

/// Stable key for deduping provider-native listings across merge and aggregation.
String marketListingDedupeKey(MarketListing row) {
  final native = row.providerListingId?.trim();
  if (native != null && native.isNotEmpty) return '${row.providerId}:$native';
  return '${row.providerId}:${row.id}';
}
