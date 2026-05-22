import 'package:blindbox_app/features/market/domain/collectible_market_grouping_tier.dart';
import 'package:flutter/foundation.dart';

/// Canonical catalog keys for a grouped market surface (not shelf ownership).
@immutable
class CollectibleMarketIdentity {
  const CollectibleMarketIdentity({
    required this.snapshotId,
    required this.groupingTier,
    this.matchedFigureId,
    this.matchedSeriesId,
    this.matchedBrandId,
    this.matchedIpId,
  });

  /// Stable rollup key (`figure:…`, `series:…`, `listing:…`).
  final String snapshotId;
  final CollectibleMarketGroupingTier groupingTier;
  final String? matchedFigureId;
  final String? matchedSeriesId;
  final String? matchedBrandId;
  final String? matchedIpId;
}
