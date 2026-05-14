import 'package:blindbox_app/models/market_listing.dart';

/// Local browse price order (UI + future `sort=price_asc` API parity).
enum MarketPriceSort {
  lowToHigh,
  highToLow,
}

extension MarketPriceSortBrowseLabel on MarketPriceSort {
  /// Compact header control copy (↑ ascending, ↓ descending).
  String get browseHeaderLabel => switch (this) {
        MarketPriceSort.lowToHigh => 'Price ↑',
        MarketPriceSort.highToLow => 'Price ↓',
      };
}

/// Returns a new list sorted by [MarketListing.currentPriceUsd] (does not mutate [listings]).
List<MarketListing> marketListingsSortedByPrice(
  List<MarketListing> listings,
  MarketPriceSort sort,
) {
  final out = List<MarketListing>.from(listings);
  out.sort((a, b) {
    final c = a.currentPriceUsd.compareTo(b.currentPriceUsd);
    return sort == MarketPriceSort.lowToHigh ? c : -c;
  });
  return out;
}
