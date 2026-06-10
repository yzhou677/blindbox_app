import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_sort.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';
import 'package:flutter/foundation.dart';

/// Whether the widget-local display-order cache should be updated.
///
/// Compares [orderIds] by value — [resolveCollectibleMarketDisplaySnapshots]
/// allocates a fresh list each build even when contents are unchanged.
bool displayOrderCacheNeedsUpdate({
  required List<String> orderIds,
  required List<String> previousOrderIds,
  required MarketPriceSort priceSort,
  required MarketPriceSort previousPriceSort,
  required String browseSignature,
  required String? previousBrowseSignature,
}) {
  return !listEquals(orderIds, previousOrderIds) ||
      priceSort != previousPriceSort ||
      browseSignature != previousBrowseSignature;
}

/// Stable collectibles feed order for paginated live browse.
///
/// When [sortByPrice] is true, every call globally sorts all loaded snapshots
/// (including after load-more). When false, gateway relevance order is kept and
/// load-more appends new ids at the bottom.
({List<CollectibleMarketSnapshot> snapshots, List<String> orderIds})
    resolveCollectibleMarketDisplaySnapshots({
  required List<CollectibleMarketSnapshot> snapshots,
  required String browseSignature,
  required MarketPriceSort priceSort,
  required bool stablePagination,
  required bool sortByPrice,
  required List<String> previousOrderIds,
  required MarketPriceSort previousPriceSort,
  required String? previousBrowseSignature,
}) {
  if (snapshots.isEmpty) {
    return (snapshots: const [], orderIds: const []);
  }

  final byId = {
    for (final snapshot in snapshots) snapshot.identity.snapshotId: snapshot,
  };

  if (sortByPrice) {
    final sorted = sortCollectibleMarketSnapshots(
      snapshots,
      priceSort,
      sortByPrice: true,
    );
    return (
      snapshots: sorted,
      orderIds: sorted.map((s) => s.identity.snapshotId).toList(),
    );
  }

  if (!stablePagination) {
    final sorted = sortCollectibleMarketSnapshots(
      snapshots,
      priceSort,
      sortByPrice: false,
    );
    return (
      snapshots: sorted,
      orderIds: sorted.map((s) => s.identity.snapshotId).toList(),
    );
  }

  final feedIds = snapshots.map((s) => s.identity.snapshotId).toList();
  final resetOrder = previousOrderIds.isEmpty ||
      previousBrowseSignature != browseSignature ||
      previousPriceSort != priceSort;

  final orderIds = resetOrder
      ? feedIds
      : [
          ...previousOrderIds.where(byId.containsKey),
          ...feedIds.where((id) => !previousOrderIds.contains(id)),
        ];

  final sorted = [
    for (final id in orderIds)
      if (byId[id] != null) byId[id]!,
  ];
  return (snapshots: sorted, orderIds: orderIds);
}
