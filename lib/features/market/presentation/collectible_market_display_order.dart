import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_sort.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';

/// Stable collectibles feed order for paginated live browse.
///
/// Price sort applies on filter/sort changes; load-more appends at the bottom.
({List<CollectibleMarketSnapshot> snapshots, List<String> orderIds})
    resolveCollectibleMarketDisplaySnapshots({
  required List<CollectibleMarketSnapshot> snapshots,
  required String browseSignature,
  required MarketPriceSort priceSort,
  required bool stablePagination,
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

  if (!stablePagination) {
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

  final feedIds = snapshots.map((s) => s.identity.snapshotId).toList();
  final resetOrder = previousOrderIds.isEmpty ||
      previousBrowseSignature != browseSignature ||
      previousPriceSort != priceSort;

  final orderIds = resetOrder
      ? sortCollectibleMarketSnapshots(
          snapshots,
          priceSort,
          sortByPrice: true,
        ).map((s) => s.identity.snapshotId).toList()
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

String collectibleMarketBrowseSignature({
  required String brandId,
  required String ipId,
  required String query,
  required bool searchResultsActive,
}) {
  return '$brandId|$ipId|$searchResultsActive|$query';
}
