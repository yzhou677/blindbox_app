import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/catalog/collectible_market_filters.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final collectibleMarketSnapshotsProvider =
    Provider<List<CollectibleMarketSnapshot>>((ref) {
  if (!CollectibleMarketSession.instance.isInstalled) return const [];
  return CollectibleMarketSession.instance.list;
});

final visibleCollectibleMarketSnapshotsProvider =
    Provider<List<CollectibleMarketSnapshot>>((ref) {
  final browse = ref.watch(marketBrowseNotifierProvider);
  final snapshots = ref.watch(collectibleMarketSnapshotsProvider);
  final q = browse.query.trim().toLowerCase();
  return snapshots
      .where(
        (s) => collectibleMarketSnapshotVisible(
          s,
          brandId: browse.brandId,
          ipId: browse.ipId,
          queryLower: q,
        ),
      )
      .toList(growable: false);
});
