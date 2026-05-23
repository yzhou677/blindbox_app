import 'package:blindbox_app/features/market/domain/market_identity_match.dart';
import 'package:blindbox_app/models/collectible.dart';

/// External marketplace browse row — transient listing state, not canonical catalog identity.
///
/// [collectible] carries presentation fields for cards/detail; taxonomy ids align with
/// the catalog universe for filters. [providerId] is a [MarketProviderId.name] wire value.
class MarketListing {
  const MarketListing({
    required this.id,
    required this.collectible,
    required this.currentPriceUsd,
    required this.priceChangePercent,
    required this.listingCount,
    this.providerId = 'mock',
    this.providerListingId,
    this.externalListingUrl,
    this.taxonomyBrandId,
    this.taxonomyIpId,
    this.catalogMatch,
    this.isTrending = false,
    this.watchingCount = 0,
    this.hasSecretFigure = false,
    this.isHardToFind = false,
  });

  final String id;
  final Collectible collectible;

  /// [MarketProviderId.name] — data layer only; UI stays provider-neutral in Phase 1.
  final String providerId;

  /// Provider-native listing key (e.g. wire `itemId`).
  final String? providerListingId;

  /// Deep link to the seller listing; null when unknown.
  final String? externalListingUrl;

  /// Typical last-sale style anchor (USD).
  final double currentPriceUsd;

  /// Week-over-week style change (can be negative).
  final double priceChangePercent;

  final int listingCount;

  /// Canonical brand key from app taxonomy (e.g. `pop_mart`); null when unknown from title.
  final String? taxonomyBrandId;

  /// Canonical IP key when this row sits under a character universe; null = no IP facet.
  final String? taxonomyIpId;

  /// Catalog identity match from listing title (data layer; not shown in UI Phase 2A).
  final MarketIdentityMatch? catalogMatch;

  final bool isTrending;

  /// Mock marketplace watchers (0 = omit “watching” signal in UI).
  final int watchingCount;

  /// Official chase / secret variant in this listing (mock).
  final bool hasSecretFigure;

  /// Few listings vs collector attention — editorial scarcity (mock).
  final bool isHardToFind;

  String get marketHeroTag => 'market-listing-image-$id';
}
