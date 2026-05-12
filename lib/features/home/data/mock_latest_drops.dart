import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';

/// Illustration-style mock art (DiceBear `thumbs`) — toy-adjacent, soft pastels, not stock photography.
String mockCollectibleArtUrl(String seed, String backgroundHex) {
  return 'https://api.dicebear.com/9.x/thumbs/png'
      '?seed=${Uri.encodeComponent(seed)}'
      '&size=256'
      '&backgroundColor=$backgroundHex';
}

/// Local mock data for the Latest Drops rail (replace with API later).
final List<Collectible> mockLatestDrops = [
  Collectible(
    id: 'drop-luna',
    name: 'Luna Astronaut',
    series: 'Moon Mischief',
    brand: 'Bubble Workshop',
    releaseDate: DateTime(2026, 4, 18),
    imageUrl: mockCollectibleArtUrl('luna-astro-moon', 'fce4ec'),
    shelfAccent: const Color(0xFFE8D4F5),
  ),
  Collectible(
    id: 'drop-miso',
    name: 'Miso Baker',
    series: 'Tiny Chefs',
    brand: 'Soft Clay Co.',
    releaseDate: DateTime(2026, 4, 12),
    imageUrl: mockCollectibleArtUrl('miso-baker-chef', 'ffe8dc'),
    shelfAccent: const Color(0xFFFFE5D4),
  ),
  Collectible(
    id: 'drop-rio',
    name: 'Rio Skater',
    series: 'City Pals',
    brand: 'Northline Toys',
    releaseDate: DateTime(2026, 3, 28),
    imageUrl: mockCollectibleArtUrl('rio-skater-city', 'd9eef9'),
    shelfAccent: const Color(0xFFD4ECF8),
  ),
  Collectible(
    id: 'drop-nori',
    name: 'Nori Gardener',
    series: 'Green Room',
    brand: 'Bubble Workshop',
    releaseDate: DateTime(2026, 3, 5),
    imageUrl: mockCollectibleArtUrl('nori-garden-soft', 'dff5ea'),
    shelfAccent: const Color(0xFFD8F0E0),
  ),
  Collectible(
    id: 'drop-puff',
    name: 'Puff Cloud',
    series: 'Sky Snuggles',
    brand: 'Dreamforge',
    releaseDate: DateTime(2026, 2, 20),
    imageUrl: mockCollectibleArtUrl('puff-cloud-sky', 'ebe9ff'),
    shelfAccent: const Color(0xFFE8E8FF),
  ),
];

Collectible? mockCollectibleById(String id) {
  for (final c in mockLatestDrops) {
    if (c.id == id) return c;
  }
  return null;
}
