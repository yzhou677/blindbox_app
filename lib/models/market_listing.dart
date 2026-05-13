import 'package:blindbox_app/models/collectible.dart';

/// Mock market row: collectible + lightweight pricing / supply signals.
class MarketListing {
  const MarketListing({
    required this.id,
    required this.collectible,
    required this.currentPriceUsd,
    required this.priceChangePercent,
    required this.listingCount,
    this.isTrending = false,
  });

  final String id;
  final Collectible collectible;

  /// Typical last-sale style anchor (USD).
  final double currentPriceUsd;

  /// Week-over-week style change (can be negative).
  final double priceChangePercent;

  final int listingCount;

  final bool isTrending;

  String get marketHeroTag => 'market-listing-image-$id';
}
