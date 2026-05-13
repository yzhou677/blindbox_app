import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';

/// Local-only market rows (replace with eBay / marketplace API later).
final List<MarketListing> mockMarketListings = [
  MarketListing(
    id: 'mkt-luna',
    collectible: Collectible(
      id: 'mkt-luna',
      name: 'Luna Astronaut',
      series: 'Moon Mischief',
      brand: 'Bubble Workshop',
      releaseDate: DateTime(2026, 4, 18),
      imageUrl: mockCollectibleArtUrl('luna-astro-moon', 'fce4ec'),
      shelfAccent: const Color(0xFFE8D4F5),
    ),
    currentPriceUsd: 118,
    priceChangePercent: 4.2,
    listingCount: 24,
    isTrending: true,
  ),
  MarketListing(
    id: 'mkt-miso',
    collectible: Collectible(
      id: 'mkt-miso',
      name: 'Miso Baker',
      series: 'Tiny Chefs',
      brand: 'Soft Clay Co.',
      releaseDate: DateTime(2026, 4, 12),
      imageUrl: mockCollectibleArtUrl('miso-baker-chef', 'ffe8dc'),
      shelfAccent: const Color(0xFFFFE5D4),
    ),
    currentPriceUsd: 64,
    priceChangePercent: -1.8,
    listingCount: 41,
    isTrending: true,
  ),
  MarketListing(
    id: 'mkt-rio',
    collectible: Collectible(
      id: 'mkt-rio',
      name: 'Rio Skater',
      series: 'City Pals',
      brand: 'Northline Toys',
      releaseDate: DateTime(2026, 3, 28),
      imageUrl: mockCollectibleArtUrl('rio-skater-city', 'd9eef9'),
      shelfAccent: const Color(0xFFD4ECF8),
    ),
    currentPriceUsd: 52,
    priceChangePercent: 0.6,
    listingCount: 18,
    isTrending: true,
  ),
  MarketListing(
    id: 'mkt-nori',
    collectible: Collectible(
      id: 'mkt-nori',
      name: 'Nori Gardener',
      series: 'Green Room',
      brand: 'Bubble Workshop',
      releaseDate: DateTime(2026, 3, 5),
      imageUrl: mockCollectibleArtUrl('nori-garden-soft', 'dff5ea'),
      shelfAccent: const Color(0xFFD8F0E0),
    ),
    currentPriceUsd: 72,
    priceChangePercent: 2.4,
    listingCount: 15,
    isTrending: true,
  ),
  MarketListing(
    id: 'mkt-puff',
    collectible: Collectible(
      id: 'mkt-puff',
      name: 'Puff Cloud',
      series: 'Sky Snuggles',
      brand: 'Dreamforge',
      releaseDate: DateTime(2026, 2, 20),
      imageUrl: mockCollectibleArtUrl('puff-cloud-sky', 'ebe9ff'),
      shelfAccent: const Color(0xFFE8E8FF),
    ),
    currentPriceUsd: 44,
    priceChangePercent: -0.9,
    listingCount: 33,
    isTrending: false,
  ),
  MarketListing(
    id: 'mkt-zen',
    collectible: Collectible(
      id: 'mkt-zen',
      name: 'Zen Sprout',
      series: 'Green Room',
      brand: 'Bubble Workshop',
      releaseDate: DateTime(2025, 11, 2),
      imageUrl: mockCollectibleArtUrl('zen-sprout-green', 'e8f5e9'),
      shelfAccent: const Color(0xFFDDF0E4),
    ),
    currentPriceUsd: 89,
    priceChangePercent: 6.1,
    listingCount: 12,
    isTrending: false,
  ),
  MarketListing(
    id: 'mkt-kumo',
    collectible: Collectible(
      id: 'mkt-kumo',
      name: 'Kumo Raincoat',
      series: 'City Pals',
      brand: 'Northline Toys',
      releaseDate: DateTime(2025, 9, 14),
      imageUrl: mockCollectibleArtUrl('kumo-rain-city', 'e3f2fd'),
      shelfAccent: const Color(0xFFD6E9FA),
    ),
    currentPriceUsd: 36,
    priceChangePercent: -3.2,
    listingCount: 56,
    isTrending: false,
  ),
];

MarketListing? mockMarketListingById(String id) {
  for (final m in mockMarketListings) {
    if (m.id == id) return m;
  }
  return null;
}

List<MarketListing> mockTrendingMarketListings() {
  return mockMarketListings.where((e) => e.isTrending).toList(growable: false);
}
