import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/data/cache/collectible_market_snapshot_cache.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/features/market/data/source/default_market_sources.dart';

/// Loads browse listings once into [MarketBrowseListingsSession] (app + tests).
Future<void> bootstrapMarketBrowseListings() async {
  if (MarketBrowseListingsSession.instance.isInstalled) return;

  final cachedSnapshots =
      await CollectibleMarketSnapshotCache.instance.readStaleFromDisk();
  if (cachedSnapshots != null && cachedSnapshots.isNotEmpty) {
    CollectibleMarketSession.instance.install(cachedSnapshots);
  }

  final repo = MarketListingsRepository(defaultMarketSources());
  final listings = enrichBrowseListingsIdentity(await repo.loadBrowseListings());
  installMarketBrowseIntelligence(listings);
}
