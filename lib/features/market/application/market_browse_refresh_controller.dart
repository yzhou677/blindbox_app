import 'package:blindbox_app/features/market/application/collectible_market_diagnostics.dart';
import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/application/market_match_diagnostics.dart';
import 'package:blindbox_app/features/market/application/market_sandbox_browse_install.dart';
import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/default_market_sources.dart';
import 'package:blindbox_app/features/market/data/source/mercari_sandbox_market_source.dart';
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
      final sessionRows = currentSessionRows();

      if (MarketSandboxConfig.isActive) {
        final mercari = MercariSandboxMarketSource();
        mercari.resetPagination();
        await mercari.fetchFirstPage();
        installSandboxMarketBrowse(
          sessionRows: sessionRows,
          mercariSource: mercari,
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
