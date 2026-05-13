import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_demand_mood.dart';

/// Mock market row: collectible + lightweight pricing / supply signals.
class MarketListing {
  const MarketListing({
    required this.id,
    required this.collectible,
    required this.currentPriceUsd,
    required this.priceChangePercent,
    required this.listingCount,
    this.isTrending = false,
    this.watchingCount = 0,
    this.isRareFind = false,
    this.demandMood = MarketDemandMood.calm,
  });

  final String id;
  final Collectible collectible;

  /// Typical last-sale style anchor (USD).
  final double currentPriceUsd;

  /// Week-over-week style change (can be negative).
  final double priceChangePercent;

  final int listingCount;

  final bool isTrending;

  /// Mock “watchers” style interest (0 = hide in UI).
  final int watchingCount;

  /// Shelf-style rarity highlight (mock).
  final bool isRareFind;

  /// Cozy demand language for optional chips.
  final MarketDemandMood demandMood;

  String get marketHeroTag => 'market-listing-image-$id';
}
