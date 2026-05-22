import 'package:blindbox_app/core/data/collectible_placeholder_art.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';

/// Illustration-style mock art (DiceBear `thumbs`) — toy-adjacent, soft pastels, not stock photography.
String mockCollectibleArtUrl(String seed, String backgroundHex) =>
    placeholderCollectibleArtUrl(seed, backgroundHex);

/// Series launches for the Latest Drops rail (replace with API later).
final List<SeriesRelease> mockSeriesReleases = [
  SeriesRelease(
    dropId: 'drop-luna',
    seriesName: 'Moon Mischief',
    brand: 'Bubble Workshop',
    ipLine: 'In-house IP',
    releaseDate: DateTime(2026, 4, 18),
    seriesImageKey: 'drop-luna',
    heroCollectible: Collectible(
      id: 'drop-luna',
      name: 'Luna Astronaut',
      series: 'Moon Mischief',
      brand: 'Bubble Workshop',
      ipLine: 'In-house IP',
      releaseDate: DateTime(2026, 4, 18),
      imageUrl: mockCollectibleArtUrl('luna-astro-moon', 'fce4ec'),
      shelfAccent: const Color(0xFFE8D4F5),
    ),
    lineup: [
      ReleaseLineupSlot(
        slotId: 'orbit-bunny',
        imageKey: 'orbit-bunny',
        name: 'Orbit Bunny',
        imageUrl: mockCollectibleArtUrl('moon-orbit-bunny', 'f3e5f5'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'star-cat',
        imageKey: 'star-cat',
        name: 'Star Cat',
        imageUrl: mockCollectibleArtUrl('moon-star-cat', 'ede7f6'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'luna',
        imageKey: 'luna',
        name: 'Luna Astronaut',
        imageUrl: mockCollectibleArtUrl('luna-astro-moon', 'fce4ec'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'comet-pup',
        imageKey: 'comet-pup',
        name: 'Comet Pup',
        imageUrl: mockCollectibleArtUrl('moon-comet-pup', 'e8eaf6'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'meteor-mouse',
        imageKey: 'meteor-mouse',
        name: 'Meteor Mouse',
        imageUrl: mockCollectibleArtUrl('moon-meteor-mouse', 'e1bee7'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'eclipse',
        imageKey: 'eclipse',
        name: 'Eclipse Visitor',
        imageUrl: null,
        isSecret: true,
      ),
    ],
    taxonomyBrandId: 'toptoy',
    taxonomyIpId: null,
  ),
  SeriesRelease(
    dropId: 'drop-miso',
    seriesName: 'Tiny Chefs',
    brand: 'Soft Clay Co.',
    ipLine: 'Foodie universe',
    releaseDate: DateTime(2026, 4, 12),
    seriesImageKey: 'drop-miso',
    heroCollectible: Collectible(
      id: 'drop-miso',
      name: 'Miso Baker',
      series: 'Tiny Chefs',
      brand: 'Soft Clay Co.',
      ipLine: 'Foodie universe',
      releaseDate: DateTime(2026, 4, 12),
      imageUrl: mockCollectibleArtUrl('miso-baker-chef', 'ffe8dc'),
      shelfAccent: const Color(0xFFFFE5D4),
    ),
    lineup: [
      ReleaseLineupSlot(
        slotId: 'miso',
        imageKey: 'miso',
        name: 'Miso Baker',
        imageUrl: mockCollectibleArtUrl('miso-baker-chef', 'ffe8dc'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'knead-bear',
        imageKey: 'knead-bear',
        name: 'Knead Bear',
        imageUrl: mockCollectibleArtUrl('chef-knead-bear', 'fff3e0'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'spice-fox',
        imageKey: 'spice-fox',
        name: 'Spice Fox',
        imageUrl: mockCollectibleArtUrl('chef-spice-fox', 'ffe0b2'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'oven-owl',
        imageKey: 'oven-owl',
        name: 'Oven Owl',
        imageUrl: mockCollectibleArtUrl('chef-oven-owl', 'ffecb3'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'midnight-snack',
        imageKey: 'midnight-snack',
        name: 'Midnight Snack',
        imageUrl: null,
        isSecret: true,
      ),
    ],
    taxonomyBrandId: 'toptoy',
    taxonomyIpId: null,
  ),
  SeriesRelease(
    dropId: 'drop-rio',
    seriesName: 'City Pals',
    brand: 'Northline Toys',
    ipLine: 'Street crew IP',
    releaseDate: DateTime(2026, 3, 28),
    seriesImageKey: 'drop-rio',
    heroCollectible: Collectible(
      id: 'drop-rio',
      name: 'Rio Skater',
      series: 'City Pals',
      brand: 'Northline Toys',
      ipLine: 'Street crew IP',
      releaseDate: DateTime(2026, 3, 28),
      imageUrl: mockCollectibleArtUrl('rio-skater-city', 'd9eef9'),
      shelfAccent: const Color(0xFFD4ECF8),
    ),
    lineup: [
      ReleaseLineupSlot(
        slotId: 'rio',
        imageKey: 'rio',
        name: 'Rio Skater',
        imageUrl: mockCollectibleArtUrl('rio-skater-city', 'd9eef9'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'bench-pigeon',
        imageKey: 'bench-pigeon',
        name: 'Bench Pigeon',
        imageUrl: mockCollectibleArtUrl('city-bench-pigeon', 'e3f2fd'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'metro-raccoon',
        imageKey: 'metro-raccoon',
        name: 'Metro Raccoon',
        imageUrl: mockCollectibleArtUrl('city-metro-raccoon', 'e1f5fe'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'tagger-fox',
        imageKey: 'tagger-fox',
        name: 'Tagger Fox',
        imageUrl: mockCollectibleArtUrl('city-tagger-fox', 'dcedc8'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'night-bus-cat',
        imageKey: 'night-bus-cat',
        name: 'Night Bus Cat',
        imageUrl: mockCollectibleArtUrl('city-night-bus-cat', 'c5cae9'),
        isSecret: false,
      ),
    ],
    taxonomyBrandId: 'tntspace',
    taxonomyIpId: null,
  ),
  SeriesRelease(
    dropId: 'drop-nori',
    seriesName: 'Green Room',
    brand: 'Bubble Workshop',
    ipLine: 'In-house IP',
    releaseDate: DateTime(2026, 3, 5),
    seriesImageKey: 'drop-nori',
    heroCollectible: Collectible(
      id: 'drop-nori',
      name: 'Nori Gardener',
      series: 'Green Room',
      brand: 'Bubble Workshop',
      ipLine: 'In-house IP',
      releaseDate: DateTime(2026, 3, 5),
      imageUrl: mockCollectibleArtUrl('nori-garden-soft', 'dff5ea'),
      shelfAccent: const Color(0xFFD8F0E0),
    ),
    lineup: [
      ReleaseLineupSlot(
        slotId: 'nori',
        imageKey: 'nori',
        name: 'Nori Gardener',
        imageUrl: mockCollectibleArtUrl('nori-garden-soft', 'dff5ea'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'fern-mouse',
        imageKey: 'fern-mouse',
        name: 'Fern Mouse',
        imageUrl: mockCollectibleArtUrl('green-fern-mouse', 'c8e6c9'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'moss-toad',
        imageKey: 'moss-toad',
        name: 'Moss Toad',
        imageUrl: mockCollectibleArtUrl('green-moss-toad', 'a5d6a7'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'vine-snail',
        imageKey: 'vine-snail',
        name: 'Vine Snail',
        imageUrl: mockCollectibleArtUrl('green-vine-snail', 'dcedc8'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'root-gnome',
        imageKey: 'root-gnome',
        name: 'Root Gnome',
        imageUrl: mockCollectibleArtUrl('green-root-gnome', 'b2dfdb'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'after-rain',
        imageKey: 'after-rain',
        name: 'After the Rain',
        imageUrl: null,
        isSecret: true,
      ),
    ],
    taxonomyBrandId: 'pop_mart',
    taxonomyIpId: null,
  ),
  SeriesRelease(
    dropId: 'drop-puff',
    seriesName: 'Sky Snuggles',
    brand: 'Dreamforge',
    ipLine: 'Cloud critters',
    releaseDate: DateTime(2026, 2, 20),
    seriesImageKey: 'drop-puff',
    heroCollectible: Collectible(
      id: 'drop-puff',
      name: 'Puff Cloud',
      series: 'Sky Snuggles',
      brand: 'Dreamforge',
      ipLine: 'Cloud critters',
      releaseDate: DateTime(2026, 2, 20),
      imageUrl: mockCollectibleArtUrl('puff-cloud-sky', 'ebe9ff'),
      shelfAccent: const Color(0xFFE8E8FF),
    ),
    lineup: [
      ReleaseLineupSlot(
        slotId: 'puff',
        imageKey: 'puff',
        name: 'Puff Cloud',
        imageUrl: mockCollectibleArtUrl('puff-cloud-sky', 'ebe9ff'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'bolt-kitten',
        imageKey: 'bolt-kitten',
        name: 'Bolt Kitten',
        imageUrl: mockCollectibleArtUrl('sky-bolt-kitten', 'e8eaf6'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'drift-bunny',
        imageKey: 'drift-bunny',
        name: 'Drift Bunny',
        imageUrl: mockCollectibleArtUrl('sky-drift-bunny', 'f3e5f5'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'nimbus-pup',
        imageKey: 'nimbus-pup',
        name: 'Nimbus Pup',
        imageUrl: mockCollectibleArtUrl('sky-nimbus-pup', 'e1bee7'),
        isSecret: false,
      ),
      ReleaseLineupSlot(
        slotId: 'storm-chaser',
        imageKey: 'storm-chaser',
        name: 'Storm Chaser',
        imageUrl: null,
        isSecret: true,
      ),
    ],
    taxonomyBrandId: 'toptoy',
    taxonomyIpId: null,
  ),
];

/// Hero collectibles for the horizontal rail (one per [SeriesRelease]).
List<Collectible> get mockLatestDrops =>
    mockSeriesReleases.map((r) => r.heroCollectible).toList(growable: false);

SeriesRelease? mockSeriesReleaseByDropId(String dropId) {
  for (final r in mockSeriesReleases) {
    if (r.dropId == dropId) return r;
  }
  return null;
}

Collectible? mockCollectibleById(String id) {
  final r = mockSeriesReleaseByDropId(id);
  return r?.heroCollectible;
}
