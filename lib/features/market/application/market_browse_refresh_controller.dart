import 'package:blindbox_app/features/market/application/collectible_market_diagnostics.dart';
import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_browse_merge.dart';
import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/application/market_match_diagnostics.dart';
import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/default_market_sources.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketBrowseRefreshProvider =
    NotifierProvider<MarketBrowseRefreshNotifier, bool>(
  MarketBrowseRefreshNotifier.new,
);

/// `true` while a manual market refresh is in flight.
class MarketBrowseRefreshNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> refresh() async {
    if (state) return;
    state = true;
    try {
      final List<MarketListing> sessionRows =
          MarketBrowseListingsSession.instance.isInstalled
              ? MarketBrowseListingsSession.instance.list
              : <MarketListing>[];

      if (MarketSandboxConfig.isActive) {
        final assetBase = assetRowsFromSession(sessionRows);
        final repo = MarketListingsRepository(sandboxMarketSources());
        final fetched = await repo.loadBrowseListings();
        final mercari = fetched
            .where((e) => e.providerId == MarketProviderId.mercari.wireName)
            .toList(growable: false);
        final merged = mergeMarketBrowseListings(
          assetRows: assetBase,
          mercariRows: mercari,
          maxMercariRows: MarketSandboxConfig.maxMercariItems,
        );
        final enriched = enrichBrowseListingsIdentity(merged);
        installMarketBrowseIntelligence(enriched);
        MarketMatchDiagnostics.logIfDebug(enriched);
        CollectibleMarketDiagnostics.logIfDebug();
      } else {
        final repo = ref.read(marketListingsRepositoryProvider);
        final enriched = enrichBrowseListingsIdentity(
          await repo.loadBrowseListings(),
        );
        installMarketBrowseIntelligence(enriched);
      }
      ref.invalidate(marketBrowseListingsProvider);
      ref.invalidate(collectibleMarketSnapshotsProvider);
      ref.invalidate(visibleCollectibleMarketSnapshotsProvider);
    } finally {
      state = false;
    }
  }
}
