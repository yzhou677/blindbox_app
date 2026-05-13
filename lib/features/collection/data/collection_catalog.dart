import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:flutter/material.dart';

/// Read-only catalog for “add to shelf” suggestions — not the shelf source of truth.
abstract final class CollectionCatalog {
  static const String _ipHirono = 'ip-hirono';
  static const String _seriesHironoOther = 'series-hirono-other-one';
  static const String _ipSkull = 'ip-skullpanda';
  static const String _seriesSkull = 'series-skull-everyday';
  static const String _ipLabubu = 'ip-labubu';
  static const String _seriesLabubu = 'series-labubu-mini';
  static const String _ipDimoo = 'ip-dimoo';
  static const String _seriesDimoo = 'series-dimoo-dino';
  static const String _ipMolly = 'ip-molly';
  static const String _seriesMolly = 'series-molly-childhood';

  static List<FigureDefinition> _hironoFigures(String seriesId, String ipId) => [
        FigureDefinition(
          id: 'fig-hirono-fox',
          seriesId: seriesId,
          ipId: ipId,
          name: 'The Fox',
          imageUrl: mockCollectibleArtUrl('hirono-fox-soft', 'f3e5f5'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-hirono-bird',
          seriesId: seriesId,
          ipId: ipId,
          name: 'The Bird',
          imageUrl: mockCollectibleArtUrl('hirono-bird-soft', 'ede7f6'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-hirono-ghost',
          seriesId: seriesId,
          ipId: ipId,
          name: 'The Ghost',
          imageUrl: mockCollectibleArtUrl('hirono-ghost-soft', 'e8eaf6'),
          rarity: 'Secret',
          isSecret: true,
        ),
      ];

  static List<FigureDefinition> _skullFigures(String seriesId, String ipId) => [
        FigureDefinition(
          id: 'fig-skull-milk',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Milk Baby',
          imageUrl: mockCollectibleArtUrl('skullpanda-milk', 'fce4ec'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-skull-panda',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Pink Panda',
          imageUrl: mockCollectibleArtUrl('skullpanda-pink', 'f8e7f0'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-skull-chase',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Midnight Visitor',
          imageUrl: mockCollectibleArtUrl('skullpanda-chase', 'e1bee7'),
          rarity: 'Chase',
          isSecret: true,
        ),
      ];

  static List<FigureDefinition> _labubuFigures(String seriesId, String ipId) => [
        FigureDefinition(
          id: 'fig-labubu-vinyl',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Exciting Macaron',
          imageUrl: mockCollectibleArtUrl('labubu-macaron', 'e8f5e9'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-labubu-heart',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Heart Robber',
          imageUrl: mockCollectibleArtUrl('labubu-heart', 'fff9c4'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-labubu-hidden',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Zimomo Guest',
          imageUrl: mockCollectibleArtUrl('labubu-zimomo', 'dcedc8'),
          rarity: 'Secret',
          isSecret: true,
        ),
      ];

  static List<FigureDefinition> _dimooFigures(String seriesId, String ipId) => [
        FigureDefinition(
          id: 'fig-dimoo-rex',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Baby Rex',
          imageUrl: mockCollectibleArtUrl('dimoo-rex', 'e3f2fd'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-dimoo-egg',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Egg Explorer',
          imageUrl: mockCollectibleArtUrl('dimoo-egg', 'fff3e0'),
          rarity: 'Regular',
          isSecret: false,
        ),
      ];

  static List<FigureDefinition> _mollyFigures(String seriesId, String ipId) => [
        FigureDefinition(
          id: 'fig-molly-painter',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Little Painter',
          imageUrl: mockCollectibleArtUrl('molly-painter', 'fff8e1'),
          rarity: 'Regular',
          isSecret: false,
        ),
        FigureDefinition(
          id: 'fig-molly-astronaut',
          seriesId: seriesId,
          ipId: ipId,
          name: 'Tiny Astronaut',
          imageUrl: mockCollectibleArtUrl('molly-astro', 'e1f5fe'),
          rarity: 'Regular',
          isSecret: false,
        ),
      ];

  /// Full IP tree for browse / suggestions (includes lines not on the default shelf).
  static List<IPDefinition> allTemplateIps() {
    return [
      IPDefinition(
        id: _ipHirono,
        name: 'Hirono',
        series: [
          SeriesDefinition(
            id: _seriesHironoOther,
            name: 'The Other One',
            brand: 'POP MART',
            ipName: 'Hirono',
            shelfAccent: const Color(0xFFF2E8DC),
            figures: _hironoFigures(_seriesHironoOther, _ipHirono),
            catalogTemplateId: _seriesHironoOther,
          ),
        ],
      ),
      IPDefinition(
        id: _ipSkull,
        name: 'Skullpanda',
        series: [
          SeriesDefinition(
            id: _seriesSkull,
            name: 'Everyday Wonderland',
            brand: 'POP MART',
            ipName: 'Skullpanda',
            shelfAccent: const Color(0xFFE8E4F8),
            figures: _skullFigures(_seriesSkull, _ipSkull),
            catalogTemplateId: _seriesSkull,
          ),
        ],
      ),
      IPDefinition(
        id: _ipLabubu,
        name: 'The Monsters',
        series: [
          SeriesDefinition(
            id: _seriesLabubu,
            name: 'Labubu Exciting Macaron',
            brand: 'POP MART',
            ipName: 'The Monsters',
            shelfAccent: const Color(0xFFE4F2EA),
            figures: _labubuFigures(_seriesLabubu, _ipLabubu),
            catalogTemplateId: _seriesLabubu,
          ),
        ],
      ),
      IPDefinition(
        id: _ipDimoo,
        name: 'Dimoo',
        series: [
          SeriesDefinition(
            id: _seriesDimoo,
            name: 'Jurassic World',
            brand: 'POP MART',
            ipName: 'Dimoo',
            shelfAccent: const Color(0xFFE4EDFA),
            figures: _dimooFigures(_seriesDimoo, _ipDimoo),
            catalogTemplateId: _seriesDimoo,
          ),
        ],
      ),
      IPDefinition(
        id: _ipMolly,
        name: 'Molly',
        series: [
          SeriesDefinition(
            id: _seriesMolly,
            name: 'My Childhood',
            brand: 'POP MART',
            ipName: 'Molly',
            shelfAccent: const Color(0xFFFFF3E0),
            figures: _mollyFigures(_seriesMolly, _ipMolly),
            catalogTemplateId: _seriesMolly,
          ),
        ],
      ),
    ];
  }

  static Iterable<SeriesDefinition> _flattenIps(List<IPDefinition> ips) sync* {
    for (final ip in ips) {
      for (final s in ip.series) {
        yield s;
      }
    }
  }

  /// Series templates the user does not already have on shelf (for add UI).
  static List<SeriesDefinition> suggestedSeries(CollectionSnapshot snap) {
    return _flattenIps(allTemplateIps())
        .where((t) => !snap.hasTemplateOnShelf(t.catalogTemplateId ?? t.id))
        .toList(growable: false);
  }

  /// Default demo shelf: user line first, then catalog-backed lines (same ids as catalog for progress keys).
  static List<SeriesDefinition> defaultShelfSeries() {
    const customSpring = 'custom-spring-picnic';
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

    final custom = SeriesDefinition(
      id: customSpring,
      name: 'Spring Picnic customs',
      brand: 'Independent',
      ipName: 'Local artist',
      shelfAccent: const Color(0xFFFCE4EC),
      figures: customFigures,
      notes: 'Hand-painted friends from last swap meet.',
      catalogTemplateId: null,
    );

    final catalog = allTemplateIps();
    final official = _flattenIps(catalog)
        .where((s) => s.id != _seriesMolly)
        .map(
          (s) => SeriesDefinition(
            id: s.id,
            name: s.name,
            brand: s.brand,
            ipName: s.ipName,
            figures: s.figures,
            shelfAccent: s.shelfAccent,
            notes: s.notes,
            catalogTemplateId: s.catalogTemplateId ?? s.id,
          ),
        )
        .toList(growable: false);

    return [custom, ...official];
  }
}
