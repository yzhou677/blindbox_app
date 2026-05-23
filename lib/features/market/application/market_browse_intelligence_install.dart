import 'package:blindbox_app/features/market/application/collectible_market_aggregator.dart';
import 'package:blindbox_app/features/market/data/cache/collectible_market_snapshot_cache.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Installs browse listings and derived collectible market snapshots.
void installMarketBrowseIntelligence(List<MarketListing> listings) {
  MarketBrowseListingsSession.instance.install(listings);
  final snapshots = buildCollectibleMarketSnapshots(listings);
  CollectibleMarketSession.instance.install(snapshots);
  final cache = CollectibleMarketSnapshotCache.instance;
  cache.writeMemory(snapshots);
  // Disk persistence is best-effort (skipped when platform plugins unavailable).
  cache.write(snapshots).ignore();
}
