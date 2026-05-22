import 'package:blindbox_app/features/market/domain/aggregation_confidence.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_identity.dart';
import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/observed_price_range.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';
import 'package:flutter/foundation.dart';

/// Lightweight aggregated market view around one collectible identity.
///
/// Derived from [MarketListing] rows — not canonical catalog or shelf state.
@immutable
class CollectibleMarketSnapshot {
  const CollectibleMarketSnapshot({
    required this.identity,
    required this.listingCount,
    required this.listingIds,
    required this.providerCoverage,
    required this.observedPriceRange,
    required this.representativeListingId,
    required this.marketMood,
    required this.rarityPresence,
    required this.aggregationConfidence,
    required this.lastObservedAt,
  });

  final CollectibleMarketIdentity identity;
  final int listingCount;
  final List<String> listingIds;
  final Map<String, int> providerCoverage;
  final ObservedPriceRange observedPriceRange;
  final String representativeListingId;
  final MarketMood marketMood;
  final RarityPresence rarityPresence;
  final AggregationConfidence aggregationConfidence;
  final DateTime lastObservedAt;
}
