import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// One provider browse page — supports calm incremental loading.
@immutable
class MarketBrowsePageResult {
  const MarketBrowsePageResult({
    required this.listings,
    this.nextCursor,
    this.hasMore = false,
    this.fromCache = false,
  });

  final List<MarketListing> listings;
  final String? nextCursor;
  final bool hasMore;
  final bool fromCache;

  static const empty = MarketBrowsePageResult(listings: []);
}
