import 'package:blindbox_app/features/market/application/chasers_probe_targets.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/features/market/domain/market_listing_title_signals.dart';
import 'package:blindbox_app/features/market/domain/market_title_clusterer.dart';
import 'package:blindbox_app/models/market_listing.dart';

const _chaseTerms = ['secret', 'chase', 'hidden', 'variant'];

/// Phase 1 lightweight heat score — identity cluster quality gates first.
double scoreChaserCluster(MarketTitleCluster cluster) {
  if (cluster.likelyAccessoryHeavy || cluster.likelyNoisy) return 0;
  if (cluster.listingCount < 2 || cluster.uniqueSellerCount < 2) return 0;

  final sighting = (cluster.listingCount / 8.0).clamp(0.0, 1.0);
  final diversity = cluster.sellerDiversity.clamp(0.0, 1.0);
  final sellerBalance =
      (cluster.uniqueSellerCount / cluster.listingCount).clamp(0.33, 1.0);

  var chaseBonus = 0.0;
  for (final title in cluster.sampleTitles) {
    final lower = title.toLowerCase();
    if (_chaseTerms.any(lower.contains)) {
      chaseBonus = 0.08;
      break;
    }
  }

  return (0.42 * sighting + 0.42 * diversity + chaseBonus) * sellerBalance;
}

List<ChasersHeatEntry> buildChaserEntriesFromProbe({
  required ChasersProbeTarget target,
  required List<MarketListing> listings,
}) {
  if (listings.isEmpty) return const [];

  final clusterer = MarketTitleClusterer(hintTokens: target.hintTokens);
  final inputs = [
    for (final row in listings)
      MarketTitleClusterInput(
        title: row.collectible.name,
        sellerUsername: row.sellerUsername,
        priceUsd: row.currentPriceUsd,
      ),
  ];
  final clusters = clusterer.cluster(inputs);
  final out = <ChasersHeatEntry>[];

  for (final cluster in clusters) {
    final heatScore = scoreChaserCluster(cluster);
    if (heatScore <= 0) continue;
    final representative = _pickRepresentative(listings, clusterer, cluster);
    if (representative == null) continue;
    out.add(
      ChasersHeatEntry(
        identityLabel: cluster.label,
        clusterKey: cluster.clusterKey,
        representativeListing: representative,
        heatScore: heatScore,
        listingCount: cluster.listingCount,
        uniqueSellerCount: cluster.uniqueSellerCount,
        brandId: target.brandId,
        ipId: target.ipId,
        ipLabel: target.ipLabel,
      ),
    );
  }
  return out;
}

/// Merge probe results — keep highest score per cluster key globally.
List<ChasersHeatEntry> mergeChaserEntries(List<ChasersHeatEntry> entries) {
  final best = <String, ChasersHeatEntry>{};
  for (final entry in entries) {
    final prev = best[entry.clusterKey];
    if (prev == null || entry.heatScore > prev.heatScore) {
      best[entry.clusterKey] = entry;
    }
  }
  final out = best.values.toList()
    ..sort((a, b) => b.heatScore.compareTo(a.heatScore));
  return out;
}

MarketListing? _pickRepresentative(
  List<MarketListing> listings,
  MarketTitleClusterer clusterer,
  MarketTitleCluster cluster,
) {
  final matched = listings
      .where(
        (row) =>
            clusterer.clusterKeyForTitle(row.collectible.name) == cluster.clusterKey,
      )
      .toList();
  if (matched.isEmpty) return null;
  if (matched.length == 1) return matched.first;

  final median = cluster.medianPriceUsd;
  matched.sort((a, b) {
    final scoreCmp = MarketListingTitleSignals.presentationScore(b)
        .compareTo(MarketListingTitleSignals.presentationScore(a));
    if (scoreCmp != 0) return scoreCmp;
    if (median != null) {
      final aDelta = (a.currentPriceUsd - median).abs();
      final bDelta = (b.currentPriceUsd - median).abs();
      final deltaCmp = aDelta.compareTo(bDelta);
      if (deltaCmp != 0) return deltaCmp;
    }
    return a.currentPriceUsd.compareTo(b.currentPriceUsd);
  });
  return matched.first;
}

List<ChasersHeatEntry> chasersHeatFromFixtureListings(List<MarketListing> items) {
  return [
    for (final row in items)
      ChasersHeatEntry(
        identityLabel: row.collectible.series.isNotEmpty
            ? row.collectible.series
            : row.collectible.name,
        clusterKey: 'fixture:${row.id}',
        representativeListing: row,
        heatScore: 1,
        listingCount: row.listingCount,
        uniqueSellerCount: 1,
        brandId: row.taxonomyBrandId ?? '',
        ipId: row.taxonomyIpId ?? '',
        ipLabel: '',
      ),
  ];
}
