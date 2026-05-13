import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:flutter/material.dart';

/// Builds the default in-memory library (swap for API + persistence later).
abstract final class CollectionSeedData {
  static CollectionSnapshot initialSnapshot() {
    const ipHirono = 'ip-hirono';
    const sHironoOther = 'series-hirono-other-one';
    const ipSkull = 'ip-skullpanda';
    const sSkull = 'series-skull-everyday';
    const ipLabubu = 'ip-labubu';
    const sLabubu = 'series-labubu-mini';
    const ipDimoo = 'ip-dimoo';
    const sDimoo = 'series-dimoo-dino';
    const customSpring = 'custom-spring-picnic';

    final hironoFigures = [
      FigureDefinition(
        id: 'fig-hirono-fox',
        seriesId: sHironoOther,
        ipId: ipHirono,
        name: 'The Fox',
        imageUrl: mockCollectibleArtUrl('hirono-fox-soft', 'f3e5f5'),
        rarity: 'Regular',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-hirono-bird',
        seriesId: sHironoOther,
        ipId: ipHirono,
        name: 'The Bird',
        imageUrl: mockCollectibleArtUrl('hirono-bird-soft', 'ede7f6'),
        rarity: 'Regular',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-hirono-ghost',
        seriesId: sHironoOther,
        ipId: ipHirono,
        name: 'The Ghost',
        imageUrl: mockCollectibleArtUrl('hirono-ghost-soft', 'e8eaf6'),
        rarity: 'Secret',
        isSecret: true,
      ),
    ];

    final skullFigures = [
      FigureDefinition(
        id: 'fig-skull-milk',
        seriesId: sSkull,
        ipId: ipSkull,
        name: 'Milk Baby',
        imageUrl: mockCollectibleArtUrl('skullpanda-milk', 'fce4ec'),
        rarity: 'Regular',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-skull-panda',
        seriesId: sSkull,
        ipId: ipSkull,
        name: 'Pink Panda',
        imageUrl: mockCollectibleArtUrl('skullpanda-pink', 'f8e7f0'),
        rarity: 'Regular',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-skull-chase',
        seriesId: sSkull,
        ipId: ipSkull,
        name: 'Midnight Visitor',
        imageUrl: mockCollectibleArtUrl('skullpanda-chase', 'e1bee7'),
        rarity: 'Chase',
        isSecret: true,
      ),
    ];

    final labubuFigures = [
      FigureDefinition(
        id: 'fig-labubu-vinyl',
        seriesId: sLabubu,
        ipId: ipLabubu,
        name: 'Exciting Macaron',
        imageUrl: mockCollectibleArtUrl('labubu-macaron', 'e8f5e9'),
        rarity: 'Regular',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-labubu-heart',
        seriesId: sLabubu,
        ipId: ipLabubu,
        name: 'Heart Robber',
        imageUrl: mockCollectibleArtUrl('labubu-heart', 'fff9c4'),
        rarity: 'Regular',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-labubu-hidden',
        seriesId: sLabubu,
        ipId: ipLabubu,
        name: 'Zimomo Guest',
        imageUrl: mockCollectibleArtUrl('labubu-zimomo', 'dcedc8'),
        rarity: 'Secret',
        isSecret: true,
      ),
    ];

    final dimooFigures = [
      FigureDefinition(
        id: 'fig-dimoo-rex',
        seriesId: sDimoo,
        ipId: ipDimoo,
        name: 'Baby Rex',
        imageUrl: mockCollectibleArtUrl('dimoo-rex', 'e3f2fd'),
        rarity: 'Regular',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-dimoo-egg',
        seriesId: sDimoo,
        ipId: ipDimoo,
        name: 'Egg Explorer',
        imageUrl: mockCollectibleArtUrl('dimoo-egg', 'fff3e0'),
        rarity: 'Regular',
        isSecret: false,
      ),
    ];

    final customFigures = [
      FigureDefinition(
        id: 'fig-custom-spring-1',
        seriesId: customSpring,
        ipId: customSpring,
        name: 'Berry Bunny',
        imageUrl: mockCollectibleArtUrl('custom-berry', 'fce4ec'),
        rarity: 'Custom',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-custom-spring-2',
        seriesId: customSpring,
        ipId: customSpring,
        name: 'Tea Cup Mouse',
        imageUrl: mockCollectibleArtUrl('custom-tea', 'e0f7fa'),
        rarity: 'Custom',
        isSecret: false,
      ),
      FigureDefinition(
        id: 'fig-custom-spring-3',
        seriesId: customSpring,
        ipId: customSpring,
        name: 'Rainbow Snail',
        imageUrl: mockCollectibleArtUrl('custom-snail', 'f3e5f5'),
        rarity: 'Custom',
        isSecret: false,
      ),
    ];

    final officialIps = [
      IPDefinition(
        id: ipHirono,
        name: 'Hirono',
        series: [
          SeriesDefinition(
            id: sHironoOther,
            name: 'The Other One',
            brand: 'POP MART',
            ipName: 'Hirono',
            shelfAccent: const Color(0xFFF2E8DC),
            figures: hironoFigures,
          ),
        ],
      ),
      IPDefinition(
        id: ipSkull,
        name: 'Skullpanda',
        series: [
          SeriesDefinition(
            id: sSkull,
            name: 'Everyday Wonderland',
            brand: 'POP MART',
            ipName: 'Skullpanda',
            shelfAccent: const Color(0xFFE8E4F8),
            figures: skullFigures,
          ),
        ],
      ),
      IPDefinition(
        id: ipLabubu,
        name: 'The Monsters',
        series: [
          SeriesDefinition(
            id: sLabubu,
            name: 'Labubu Exciting Macaron',
            brand: 'POP MART',
            ipName: 'The Monsters',
            shelfAccent: const Color(0xFFE4F2EA),
            figures: labubuFigures,
          ),
        ],
      ),
      IPDefinition(
        id: ipDimoo,
        name: 'Dimoo',
        series: [
          SeriesDefinition(
            id: sDimoo,
            name: 'Jurassic World',
            brand: 'POP MART',
            ipName: 'Dimoo',
            shelfAccent: const Color(0xFFE4EDFA),
            figures: dimooFigures,
          ),
        ],
      ),
    ];

    final customSeries = [
      SeriesDefinition(
        id: customSpring,
        name: 'Spring Picnic customs',
        brand: 'Independent',
        ipName: 'Your shelf',
        shelfAccent: const Color(0xFFFCE4EC),
        figures: customFigures,
        notes: 'Hand-painted friends from last swap meet.',
      ),
    ];

    final figureStates = <String, TrackedFigure>{
      'fig-hirono-fox': const TrackedFigure(figureId: 'fig-hirono-fox', owned: true, wishlist: false),
      'fig-hirono-bird': const TrackedFigure(figureId: 'fig-hirono-bird', owned: false, wishlist: true),
      'fig-skull-milk': const TrackedFigure(figureId: 'fig-skull-milk', owned: true, wishlist: false),
      'fig-skull-panda': const TrackedFigure(figureId: 'fig-skull-panda', owned: false, wishlist: true),
      'fig-labubu-vinyl': const TrackedFigure(figureId: 'fig-labubu-vinyl', owned: true, wishlist: false),
      'fig-labubu-heart': const TrackedFigure(figureId: 'fig-labubu-heart', owned: false, wishlist: true),
      'fig-custom-spring-1': const TrackedFigure(figureId: 'fig-custom-spring-1', owned: true, wishlist: false),
      'fig-custom-spring-2': const TrackedFigure(figureId: 'fig-custom-spring-2', owned: true, wishlist: false),
      'fig-custom-spring-3': const TrackedFigure(figureId: 'fig-custom-spring-3', owned: false, wishlist: true),
    };

    return CollectionSnapshot(
      officialIps: officialIps,
      customSeries: customSeries,
      figureStates: figureStates,
    );
  }
}
