import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_feed_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_controller.dart';
import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/application/market_match_diagnostics.dart';
import 'package:blindbox_app/features/market/application/market_sandbox_browse_install.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/mercari_sandbox_market_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketBrowseRefreshProvider =    NotifierProvider<MarketBrowseRefreshNotifier, bool>(
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
      if (MarketGatewayConfig.isActive) {
        await ref.read(marketLiveBrowseControllerProvider.notifier).refresh();
      } else if (MarketSandboxConfig.isActive) {
        ref
            .read(marketFeedBrowseNotifierProvider.notifier)
            .resetTaxonomyFiltersForSandbox();
        final mercari = MercariSandboxMarketSource();
        mercari.resetPagination();
        await mercari.fetchFirstPage();
        installSandboxMarketBrowse(
          sessionRows: ref.read(marketBrowseListingsProvider),
        );
      } else {
        final repo = ref.read(marketListingsRepositoryProvider);
        final enriched = enrichBrowseListingsIdentity(
          await repo.loadBrowseListings(),
        );
        installMarketBrowseIntelligence(enriched);
        MarketMatchDiagnostics.logIfDebug(enriched);
      }
      ref.invalidate(marketBrowseListingsProvider);
      ref.invalidate(collectibleMarketSnapshotsProvider);
      ref.invalidate(visibleCollectibleMarketSnapshotsProvider);
    } finally {
      state = false;
    }
  }
}
