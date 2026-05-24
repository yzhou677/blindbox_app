import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_controller.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/application/market_sandbox_browse_install.dart';
import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/mercari_sandbox_market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketLiveBrowseHasMoreProvider = Provider<bool>((ref) {
  if (MarketGatewayConfig.isActive) {
    final live = ref.watch(marketLiveBrowseControllerProvider);
    final cursor = live.nextCursor?.trim();
    return live.hasMore &&
        !live.isLoadingInitial &&
        cursor != null &&
        cursor.isNotEmpty &&
        live.listings.length < MarketGatewayConfig.maxLiveRows;
  }
  if (!MarketSandboxConfig.isActive) return false;
  final batch =
      MarketProviderBrowseCache.instance.batchFor(MarketProviderId.mercari);
  if (batch == null) return false;
  return batch.hasMore &&
      batch.listings.length < MarketSandboxConfig.maxMercariTotalRows;
});

/// @deprecated Use [marketLiveBrowseHasMoreProvider].
final marketMercariHasMoreProvider = marketLiveBrowseHasMoreProvider;

final marketBrowseLoadMoreProvider =
    NotifierProvider<MarketBrowseLoadMoreNotifier, bool>(
  MarketBrowseLoadMoreNotifier.new,
);

/// `true` while a calm "load more" request is in flight.
class MarketBrowseLoadMoreNotifier extends Notifier<bool> {
  final MercariSandboxMarketSource _mercari = MercariSandboxMarketSource();

  @override
  bool build() => false;

  Future<void> loadMore() async {
    if (state) return;
    if (!ref.read(marketLiveBrowseHasMoreProvider)) return;

    state = true;
    try {
      if (MarketGatewayConfig.isActive) {
        await ref.read(marketLiveBrowseControllerProvider.notifier).loadMore();
      } else if (MarketSandboxConfig.isActive) {
        await _mercari.fetchNextPage();
        installSandboxMarketBrowse(
          sessionRows: ref.read(marketBrowseListingsProvider),
        );
      }
      ref.invalidate(marketBrowseListingsProvider);
      ref.invalidate(collectibleMarketSnapshotsProvider);
      ref.invalidate(visibleCollectibleMarketSnapshotsProvider);
    } finally {
      state = false;
    }
  }
}
