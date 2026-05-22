import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_grouping_tier.dart';
import 'package:flutter/foundation.dart';

/// Debug-only summary of collectible aggregation tiers.
final class CollectibleMarketDiagnostics {
  static void logIfDebug() {
    if (!kDebugMode) return;
    if (!CollectibleMarketSession.instance.isInstalled) return;

    var figure = 0;
    var series = 0;
    var fallback = 0;
    for (final snap in CollectibleMarketSession.instance.list) {
      switch (snap.identity.groupingTier) {
        case CollectibleMarketGroupingTier.figure:
          figure++;
        case CollectibleMarketGroupingTier.series:
          series++;
        case CollectibleMarketGroupingTier.listingFallback:
          fallback++;
      }
    }
    final total = figure + series + fallback;
    debugPrint(
      'CollectibleMarketDiagnostics: total=$total figure=$figure '
      'series=$series listingFallback=$fallback',
    );
  }
}
