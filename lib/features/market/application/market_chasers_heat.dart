import 'package:blindbox_app/features/market/application/market_chasers_controller.dart';
import 'package:blindbox_app/features/market/data/chasers/market_chasers_config.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/features/market/domain/market_title_clusterer.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top Phase 1 chaser identities — empty unless [MarketChasersConfig.enablePhase1Scoring].
final marketChasersHeatProvider = Provider<List<ChasersHeatEntry>>((ref) {
  if (!MarketChasersConfig.enablePhase1Scoring) return const [];
  return ref.watch(marketChasersControllerProvider).entries;
});

/// Runs title clustering on browse listings for spike/validation (debug tooling).
List<MarketTitleCluster> clusterMarketListingTitles(
  List<MarketListing> listings, {
  List<String> hintTokens = const [],
}) {
  final clusterer = MarketTitleClusterer(hintTokens: hintTokens);
  final inputs = [
    for (final row in listings)
      MarketTitleClusterInput(
        title: row.collectible.name,
        sellerUsername: row.sellerUsername,
        priceUsd: row.currentPriceUsd,
      ),
  ];
  return clusterer.cluster(inputs);
}
