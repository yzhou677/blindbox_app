import 'package:blindbox_app/features/market/application/collectible_market_mood_rules.dart';
import 'package:blindbox_app/features/market/application/market_listing_dedupe.dart';
import 'package:blindbox_app/features/market/domain/aggregation_confidence.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_grouping_tier.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_identity.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/observed_price_range.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';
import 'package:blindbox_app/models/market_listing.dart';

final int _mediumRank = MarketMatchConfidence.medium.rank;

/// Builds collectible-centered snapshots from enriched browse listings.
List<CollectibleMarketSnapshot> buildCollectibleMarketSnapshots(
  List<MarketListing> listings,
) {
  final buckets = <String, List<MarketListing>>{};
  final identities = <String, CollectibleMarketIdentity>{};

  for (final row in listings) {
    final identity = _identityForListing(row);
    identities[identity.snapshotId] = identity;
    buckets.putIfAbsent(identity.snapshotId, () => []).add(row);
  }

  final now = DateTime.now();
  final out = <CollectibleMarketSnapshot>[];

  for (final entry in buckets.entries) {
    final identity = identities[entry.key]!;
    final deduped = _dedupeListings(entry.value);
    if (deduped.isEmpty) continue;

    final prices = deduped.map((e) => e.currentPriceUsd).toList()..sort();
    final priceRange = ObservedPriceRange(
      minUsd: prices.first,
      maxUsd: prices.last,
    );

    final providerCoverage = <String, int>{};
    for (final row in deduped) {
      providerCoverage[row.providerId] =
          (providerCoverage[row.providerId] ?? 0) + 1;
    }

    final avgChange = deduped.isEmpty
        ? 0.0
        : deduped.map((e) => e.priceChangePercent).reduce((a, b) => a + b) /
            deduped.length;

    out.add(
      CollectibleMarketSnapshot(
        identity: identity,
        listingCount: deduped.length,
        listingIds: [for (final r in deduped) r.id],
        providerCoverage: Map.unmodifiable(providerCoverage),
        observedPriceRange: priceRange,
        representativeListingId: _pickRepresentative(deduped, priceRange).id,
        marketMood: resolveMarketMood(
          listingCount: deduped.length,
          avgPriceChangePercent: avgChange,
          anyHardToFind: deduped.any((e) => e.isHardToFind),
        ),
        rarityPresence: resolveRarityPresence(deduped),
        aggregationConfidence: _aggregationConfidence(identity, deduped),
        lastObservedAt: now,
      ),
    );
  }

  out.sort((a, b) => b.listingCount.compareTo(a.listingCount));
  return out;
}

CollectibleMarketIdentity _identityForListing(MarketListing row) {
  final match = row.catalogMatch;
  if (match != null &&
      match.hasFigure &&
      match.confidence.rank >= _mediumRank) {
    final figureId = match.matchedFigureId!.trim();
    return CollectibleMarketIdentity(
      snapshotId: 'figure:$figureId',
      groupingTier: CollectibleMarketGroupingTier.figure,
      matchedFigureId: figureId,
      matchedSeriesId: match.matchedSeriesId,
      matchedBrandId: match.matchedBrandId,
      matchedIpId: match.matchedIpId,
    );
  }

  if (match != null &&
      match.hasSeries &&
      !match.hasFigure &&
      match.confidence.rank >= _mediumRank) {
    final seriesId = match.matchedSeriesId!.trim();
    return CollectibleMarketIdentity(
      snapshotId: 'series:$seriesId',
      groupingTier: CollectibleMarketGroupingTier.series,
      matchedSeriesId: seriesId,
      matchedBrandId: match.matchedBrandId,
      matchedIpId: match.matchedIpId,
    );
  }

  return CollectibleMarketIdentity(
    snapshotId: 'listing:${row.id}',
    groupingTier: CollectibleMarketGroupingTier.listingFallback,
    matchedBrandId: row.taxonomyBrandId ?? match?.matchedBrandId,
    matchedIpId: row.taxonomyIpId ?? match?.matchedIpId,
    matchedSeriesId: match?.matchedSeriesId,
    matchedFigureId: match?.matchedFigureId,
  );
}

List<MarketListing> _dedupeListings(List<MarketListing> rows) {
  final seen = <String>{};
  final out = <MarketListing>[];
  for (final row in rows) {
    final key = marketListingDedupeKey(row);
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(row);
  }
  return out;
}

MarketListing _pickRepresentative(
  List<MarketListing> rows,
  ObservedPriceRange range,
) {
  MarketListing? best;
  var bestRank = -1;
  for (final row in rows) {
    final rank = row.catalogMatch?.confidence.rank ?? -1;
    if (rank > bestRank) {
      bestRank = rank;
      best = row;
    }
  }
  best ??= rows.first;

  if (rows.length == 1) return best;

  final target = range.midpoint;
  MarketListing closest = best;
  var closestDelta = (closest.currentPriceUsd - target).abs();
  for (final row in rows) {
    final delta = (row.currentPriceUsd - target).abs();
    if (delta < closestDelta) {
      closest = row;
      closestDelta = delta;
    }
  }
  return closest;
}

AggregationConfidence _aggregationConfidence(
  CollectibleMarketIdentity identity,
  List<MarketListing> rows,
) {
  if (identity.groupingTier == CollectibleMarketGroupingTier.listingFallback) {
    final match = rows.first.catalogMatch;
    if (match == null || match.confidence == MarketMatchConfidence.none) {
      return AggregationConfidence.none;
    }
    return _mapMatchConfidence(match.confidence, cap: AggregationConfidence.low);
  }

  var minRank = MarketMatchConfidence.exact.rank;
  for (final row in rows) {
    final rank = row.catalogMatch?.confidence.rank ?? 0;
    if (rank < minRank) minRank = rank;
  }

  final minConf = MarketMatchConfidence.values[minRank];
  if (identity.groupingTier == CollectibleMarketGroupingTier.series) {
    return _mapMatchConfidence(minConf, cap: AggregationConfidence.medium);
  }
  return _mapMatchConfidence(minConf);
}

AggregationConfidence _mapMatchConfidence(
  MarketMatchConfidence confidence, {
  AggregationConfidence cap = AggregationConfidence.high,
}) {
  final mapped = switch (confidence) {
    MarketMatchConfidence.none => AggregationConfidence.none,
    MarketMatchConfidence.low => AggregationConfidence.low,
    MarketMatchConfidence.medium => AggregationConfidence.medium,
    MarketMatchConfidence.high => AggregationConfidence.high,
    MarketMatchConfidence.exact => AggregationConfidence.high,
  };
  if (mapped.rank > cap.rank) return cap;
  return mapped;
}
