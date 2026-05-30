import 'package:blindbox_app/features/market/application/active_market_browse_query.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_controller.dart';
import 'package:blindbox_app/features/market/catalog/collectible_market_filters.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final collectibleMarketSnapshotsProvider =
    Provider<List<CollectibleMarketSnapshot>>((ref) {
  if (!CollectibleMarketSession.instance.isInstalled) return const [];
  return CollectibleMarketSession.instance.list;
});

final visibleCollectibleMarketSnapshotsProvider =
    Provider<List<CollectibleMarketSnapshot>>((ref) {
  final query = ref.watch(activeMarketBrowseQueryProvider);
  final snapshots = ref.watch(collectibleMarketSnapshotsProvider);

  if (MarketGatewayConfig.isActive) {
    ref.watch(marketLiveBrowseControllerProvider);
    return snapshots;
  }

  final facets = activeMarketBrowseVisibleFilterFacets(query);
  return snapshots
      .where(
        (s) => collectibleMarketSnapshotVisible(
          s,
          brandId: facets.brandId,
          ipId: facets.ipId,
          queryLower: facets.queryLower,
        ),
      )
      .toList(growable: false);
});
