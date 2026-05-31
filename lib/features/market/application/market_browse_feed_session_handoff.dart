import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_controller.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feed browse rows to paint on [MarketScreen] (gateway handoff hides stale session).
List<CollectibleMarketSnapshot> marketBrowseFeedResultsForDisplay({
  required List<CollectibleMarketSnapshot> sorted,
  required bool sessionTransitioning,
  required bool immersive,
  required String activeSearchText,
  bool? gatewayActive,
}) {
  if (!shouldHideStaleGatewayFeedRows(
    gatewayActive: gatewayActive ?? MarketGatewayConfig.isActive,
    sessionTransitioning: sessionTransitioning,
    immersive: immersive,
    activeSearchText: activeSearchText,
  )) {
    return sorted;
  }
  return const [];
}

/// True when the last [CollectibleMarketSession] install must not be shown on feed root.
bool shouldHideStaleGatewayFeedRows({
  required bool sessionTransitioning,
  required bool immersive,
  required String activeSearchText,
  bool? gatewayActive,
}) {
  final gateway = gatewayActive ?? MarketGatewayConfig.isActive;
  if (!gateway || immersive) return false;
  if (!sessionTransitioning) return false;
  return activeSearchText.trim().isEmpty;
}

/// Clears the last gateway [CollectibleMarketSession] install before feed handoff.
void resetCollectibleMarketSessionForGatewayFeedHandoff() {
  CollectibleMarketSession.instance.reset();
}

/// Drops stale gateway rows and starts feed handoff after search exits to browse root.
void beginFeedBrowseSessionHandoff(WidgetRef ref, {required String reason}) {
  if (!MarketGatewayConfig.isActive) return;
  resetCollectibleMarketSessionForGatewayFeedHandoff();
  ref.invalidate(collectibleMarketSnapshotsProvider);
  ref
      .read(marketLiveBrowseControllerProvider.notifier)
      .rehandoffActiveQuery(reason: reason);
}
