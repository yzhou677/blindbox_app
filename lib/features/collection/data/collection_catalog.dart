import 'package:blindbox_app/core/data/collectible_placeholder_art.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Read-only catalog for “add to shelf” suggestions — not the shelf source of truth.
abstract final class CollectionCatalog {
  static const String _taxonomyBrandPopMart = 'pop_mart';

  static const String _ipHirono = 'hirono';
  static const String _seriesHironoOther = 'series-hirono-other-one';
  static const String _ipSkull = 'skullpanda';
  static const String _seriesSkull = 'series-skull-everyday';
  static const String _ipTheMonsters = 'the_monsters';
  static const String _seriesLabubu = 'series-labubu-mini';
  static const String _ipDimoo = 'dimoo';
  static const String _seriesDimoo = 'series-dimoo-dino';
  static const String _ipMolly = 'molly';
  static const String _seriesMolly = 'series-molly-childhood';

  static List<CatalogFigure> _hironoFigures(String seriesTemplateId) => [
        CatalogFigure(
          templateFigureId: 'fig-hirono-fox',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'The Fox',
          imageUrl: placeholderCollectibleArtUrl('hirono-fox-soft', 'f3e5f5'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipHirono,
        ),
        CatalogFigure(
          templateFigureId: 'fig-hirono-bird',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'The Bird',
          imageUrl: placeholderCollectibleArtUrl('hirono-bird-soft', 'ede7f6'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipHirono,
        ),
        CatalogFigure(
          templateFigureId: 'fig-hirono-ghost',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'The Ghost',
          imageUrl: placeholderCollectibleArtUrl('hirono-ghost-soft', 'e8eaf6'),
          rarity: 'Secret',
          isSecret: true,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipHirono,
        ),
      ];

  static List<CatalogFigure> _skullFigures(String seriesTemplateId) => [
        CatalogFigure(
          templateFigureId: 'fig-skull-milk',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Milk Baby',
          imageUrl: placeholderCollectibleArtUrl('skullpanda-milk', 'fce4ec'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipSkull,
        ),
        CatalogFigure(
          templateFigureId: 'fig-skull-panda',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Pink Panda',
          imageUrl: placeholderCollectibleArtUrl('skullpanda-pink', 'f8e7f0'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipSkull,
        ),
        CatalogFigure(
          templateFigureId: 'fig-skull-chase',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Midnight Visitor',
          imageUrl: placeholderCollectibleArtUrl('skullpanda-chase', 'e1bee7'),
          rarity: 'Chase',
          isSecret: true,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipSkull,
        ),
      ];

  static List<CatalogFigure> _labubuFigures(String seriesTemplateId) => [
        CatalogFigure(
          templateFigureId: 'fig-labubu-vinyl',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Exciting Macaron',
          imageUrl: placeholderCollectibleArtUrl('labubu-macaron', 'e8f5e9'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipTheMonsters,
        ),
        CatalogFigure(
          templateFigureId: 'fig-labubu-heart',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Heart Robber',
          imageUrl: placeholderCollectibleArtUrl('labubu-heart', 'fff9c4'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipTheMonsters,
        ),
        CatalogFigure(
          templateFigureId: 'fig-labubu-hidden',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Zimomo Guest',
          imageUrl: placeholderCollectibleArtUrl('labubu-zimomo', 'dcedc8'),
          rarity: 'Secret',
          isSecret: true,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: _ipTheMonsters,
        ),
      ];

  static List<CatalogFigure> _dimooFigures(String seriesTemplateId) => [
        CatalogFigure(
          templateFigureId: 'fig-dimoo-rex',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Baby Rex',
          imageUrl: placeholderCollectibleArtUrl('dimoo-rex', 'e3f2fd'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: null,
        ),
        CatalogFigure(
          templateFigureId: 'fig-dimoo-egg',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Egg Explorer',
          imageUrl: placeholderCollectibleArtUrl('dimoo-egg', 'fff3e0'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: null,
        ),
      ];

  static List<CatalogFigure> _mollyFigures(String seriesTemplateId) => [
        CatalogFigure(
          templateFigureId: 'fig-molly-painter',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Little Painter',
          imageUrl: placeholderCollectibleArtUrl('molly-painter', 'fff8e1'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: null,
        ),
        CatalogFigure(
          templateFigureId: 'fig-molly-astronaut',
          catalogSeriesTemplateId: seriesTemplateId,
          name: 'Tiny Astronaut',
          imageUrl: placeholderCollectibleArtUrl('molly-astro', 'e1f5fe'),
          rarity: 'Regular',
          isSecret: false,
          taxonomyBrandId: _taxonomyBrandPopMart,
          taxonomyIpId: null,
        ),
      ];

  /// Full IP tree for browse / suggestions (includes series not on the default shelf).
  static List<IPDefinition> allTemplateIps() {
    return [
      IPDefinition(
        id: _ipHirono,
        name: 'Hirono',
        catalogSeries: [
          CatalogSeries(
            templateId: _seriesHironoOther,
            name: 'The Other One',
            brand: 'POP MART',
            ipName: 'Hirono',
            shelfAccent: const Color(0xFFF2E8DC),
            figures: _hironoFigures(_seriesHironoOther),
            taxonomyBrandId: _taxonomyBrandPopMart,
            taxonomyIpId: _ipHirono,
          ),
        ],
      ),
      IPDefinition(
        id: _ipSkull,
        name: 'Skullpanda',
        catalogSeries: [
          CatalogSeries(
            templateId: _seriesSkull,
            name: 'Everyday Wonderland',
            brand: 'POP MART',
            ipName: 'Skullpanda',
            shelfAccent: const Color(0xFFE8E4F8),
            figures: _skullFigures(_seriesSkull),
            taxonomyBrandId: _taxonomyBrandPopMart,
            taxonomyIpId: _ipSkull,
          ),
        ],
      ),
      IPDefinition(
        id: _ipTheMonsters,
        name: 'THE MONSTERS',
        catalogSeries: [
          CatalogSeries(
            templateId: _seriesLabubu,
            name: 'Labubu Exciting Macaron',
            brand: 'POP MART',
            ipName: 'THE MONSTERS',
            shelfAccent: const Color(0xFFE4F2EA),
            figures: _labubuFigures(_seriesLabubu),
            taxonomyBrandId: _taxonomyBrandPopMart,
            taxonomyIpId: _ipTheMonsters,
          ),
        ],
      ),
      IPDefinition(
        id: _ipDimoo,
        name: 'Dimoo',
        catalogSeries: [
          CatalogSeries(
            templateId: _seriesDimoo,
            name: 'Jurassic World',
            brand: 'POP MART',
            ipName: 'Dimoo',
            shelfAccent: const Color(0xFFE4EDFA),
            figures: _dimooFigures(_seriesDimoo),
            taxonomyBrandId: _taxonomyBrandPopMart,
            taxonomyIpId: null,
          ),
        ],
      ),
      IPDefinition(
        id: _ipMolly,
        name: 'Molly',
        catalogSeries: [
          CatalogSeries(
            templateId: _seriesMolly,
            name: 'My Childhood',
            brand: 'POP MART',
            ipName: 'Molly',
            shelfAccent: const Color(0xFFFFF3E0),
            figures: _mollyFigures(_seriesMolly),
            taxonomyBrandId: _taxonomyBrandPopMart,
            taxonomyIpId: null,
          ),
        ],
      ),
    ];
  }

  static Iterable<CatalogSeries> _flattenIps(List<IPDefinition> ips) sync* {
    for (final ip in ips) {
      for (final s in ip.catalogSeries) {
        yield s;
      }
    }
  }

  /// Series templates the user does not already have on shelf (for add UI).
  static List<CatalogSeries> suggestedSeries(CollectionSnapshot snap) {
    return _flattenIps(allTemplateIps())
        .where((t) => !snap.hasTemplateOnShelf(t.templateId))
        .toList(growable: false);
  }

  /// Default demo shelf: user series first, then catalog-backed series (same ids as catalog for progress keys).
  static List<ShelfSeries> defaultShelfSeries() {
    const customSpring = 'custom-spring-picnic';
    final customFigures = [
      ShelfFigure(
        id: 'fig-custom-spring-1',
        seriesId: customSpring,
        name: 'Berry Bunny',
        imageUrl: placeholderCollectibleArtUrl('custom-berry', 'fce4ec'),
        rarity: 'Custom',
        isSecret: false,
      ),
      ShelfFigure(
        id: 'fig-custom-spring-2',
        seriesId: customSpring,
        name: 'Tea Cup Mouse',
        imageUrl: placeholderCollectibleArtUrl('custom-tea', 'e0f7fa'),
        rarity: 'Custom',
        isSecret: false,
      ),
      ShelfFigure(
        id: 'fig-custom-spring-3',
        seriesId: customSpring,
        name: 'Rainbow Snail',
        imageUrl: placeholderCollectibleArtUrl('custom-snail', 'f3e5f5'),
        rarity: 'Custom',
        isSecret: false,
      ),
    ];

    final custom = ShelfSeries(
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
        .where((s) => s.templateId != _seriesMolly)
        .map(shelfSeriesMirrorCatalogTemplate)
        .toList(growable: false);

    return [custom, ...official];
  }
}
