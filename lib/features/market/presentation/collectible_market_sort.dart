import 'package:blindbox_app/features/market/application/collectible_market_display_resolver.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';

/// Sort collectible snapshots by density or representative listing price.
List<CollectibleMarketSnapshot> sortCollectibleMarketSnapshots(
  List<CollectibleMarketSnapshot> snapshots,
  MarketPriceSort priceSort, {
  bool sortByPrice = false,
}) {
  final out = List<CollectibleMarketSnapshot>.from(snapshots);
  if (sortByPrice) {
    out.sort((a, b) {
      final pa = representativeListing(a)?.currentPriceUsd ?? 0;
      final pb = representativeListing(b)?.currentPriceUsd ?? 0;
      final c = pa.compareTo(pb);
      return priceSort == MarketPriceSort.lowToHigh ? c : -c;
    });
    return out;
  }
  out.sort((a, b) => b.listingCount.compareTo(a.listingCount));
  return out;
}
