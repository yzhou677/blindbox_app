import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Identity-level market heat row for the Chasers rail.
@immutable
class ChasersHeatEntry {
  const ChasersHeatEntry({
    required this.identityLabel,
    required this.clusterKey,
    required this.representativeListing,
    required this.heatScore,
    required this.listingCount,
    required this.uniqueSellerCount,
    required this.brandId,
    required this.ipId,
    required this.ipLabel,
  });

  final String identityLabel;
  final String clusterKey;
  final MarketListing representativeListing;
  final double heatScore;
  final int listingCount;
  final int uniqueSellerCount;
  final String brandId;
  final String ipId;
  final String ipLabel;
}
