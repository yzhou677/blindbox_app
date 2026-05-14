import 'package:blindbox_app/models/collectible.dart';

/// Mock market row: collectible + lightweight pricing / shelf signals.
///
/// [taxonomyBrandId] / [taxonomyIpId] align with app market taxonomy for filters;
/// API rows can populate these from server `brandKey` / `ipKey`.
class MarketListing {
  const MarketListing({
    required this.id,
    required this.collectible,
    required this.currentPriceUsd,
    required this.priceChangePercent,
    required this.listingCount,
    required this.taxonomyBrandId,
    this.taxonomyIpId,
    this.isTrending = false,
    this.watchingCount = 0,
    this.hasSecretFigure = false,
    this.isHardToFind = false,
  });

  final String id;
  final Collectible collectible;

  /// Typical last-sale style anchor (USD).
  final double currentPriceUsd;

  /// Week-over-week style change (can be negative).
  final double priceChangePercent;

  final int listingCount;

  /// Canonical brand key from app taxonomy (e.g. `pop_mart`).
  final String taxonomyBrandId;

  /// Canonical IP key when this row sits under a character universe; null = no IP facet.
  final String? taxonomyIpId;

  final bool isTrending;

  /// Mock marketplace watchers (0 = omit “watching” signal in UI).
  final int watchingCount;

  /// Official chase / secret variant in this listing (mock).
  final bool hasSecretFigure;

  /// Few listings vs collector attention — editorial scarcity (mock).
  final bool isHardToFind;

  String get marketHeroTag => 'market-listing-image-$id';
}
