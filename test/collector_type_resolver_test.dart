import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as seed;
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_stat_keys.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfSeries _seriesWithFigures({
  required String id,
  required List<ShelfFigure> figures,
  String? brandId,
  String? ipId,
  String? catalogTemplateId,
  String? notes,
  String? customCover,
}) {
  return ShelfSeries(
    id: id,
    name: 'Series $id',
    brand: 'POP MART',
    ipName: 'IP',
    figures: figures,
    shelfAccent: const Color(0xFFE4F2EA),
    taxonomyBrandId: brandId ?? 'pop_mart',
    taxonomyIpId: ipId ?? 'the_monsters',
    catalogTemplateId: catalogTemplateId,
    notes: notes,
    customCoverImageUri: customCover,
  );
}

TrackedFigure _owned(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.owned);

TrackedFigure _wish(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.wishlist);

void main() {
  test('empty shelf resolves to wanderer', () {
    final snap = CollectionSnapshot.emptyTest();
    final profile = interpretShelf(snap);
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.wanderer);
  });

  test('hunter when multiple secrets owned', () {
    final series = _seriesWithFigures(
      id: 's1',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'Secret A',
          rarity: 'Secret',
          isSecret: true,
        ),
        const ShelfFigure(
          id: 'b',
          seriesId: 's1',
          name: 'Secret B',
          rarity: 'Secret',
          isSecret: true,
        ),
        const ShelfFigure(
          id: 'c',
          seriesId: 's1',
          name: 'Regular',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {'a': _owned('a'), 'b': _owned('b')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.hunter);
  });

  test('completionist when series fully owned', () {
    final series = _seriesWithFigures(
      id: 's1',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'b',
          seriesId: 's1',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final series2 = _seriesWithFigures(
      id: 's2',
      ipId: 'hirono',
      figures: [
        const ShelfFigure(
          id: 'c',
          seriesId: 's2',
          name: 'C',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series, series2],
      figureStates: {'a': _owned('a'), 'b': _owned('b'), 'c': _owned('c')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.completionist);
  });

  test('daydream collector when wishlist dominates', () {
    final series = _seriesWithFigures(
      id: 's1',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'R',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'b',
          seriesId: 's1',
          name: 'B',
          rarity: 'R',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'c',
          seriesId: 's1',
          name: 'C',
          rarity: 'R',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'd',
          seriesId: 's1',
          name: 'D',
          rarity: 'R',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {
        'a': _wish('a'),
        'b': _wish('b'),
        'c': _wish('c'),
        'd': _wish('d'),
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.daydreamCollector);
  });

  test('signature hash changes when ownership changes', () {
    final series = testShelfSeries();
    final before = CollectionSnapshot(shelfSeries: [series], figureStates: {});
    final after = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {'fig_test_0': _owned('fig_test_0')},
    );
    expect(
      computeCollectorTypeSignatureHash(before),
      isNot(computeCollectorTypeSignatureHash(after)),
    );
  });

  test('brand breakdown merges variant taxonomy keys', () {
    final s1 = testShelfSeries(
      id: 's1',
      taxonomyBrandId: 'pop_mart',
      brand: 'POP MART',
    );
    final s2 = testShelfSeries(
      id: 's2',
      taxonomyBrandId: 'POP MART',
      brand: 'Popmart',
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2],
      figureStates: const {},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.stats.brandBreakdown.length, 1);
    expect(identity.stats.brandBreakdown.values.single, 2);
    expect(
      canonicalizeStatKey(identity.stats.brandBreakdown.keys.single),
      'popmart',
    );
  });

  test('trend chaser with recent catalog releases', () {
    final catalog = CatalogSeedBundle(
      brands: const [],
      ips: const [],
      series: [
        seed.CatalogSeries(
          id: 'recent_series',
          brandId: 'pop_mart',
          ipId: 'the_monsters',
          displayName: 'Recent',
          releaseDate: '2026-03-01',
          isBlindBox: true,
          imageKey: 'recent_series',
        ),
        seed.CatalogSeries(
          id: 'recent_series_2',
          brandId: 'finding_unicorn',
          ipId: 'hirono',
          displayName: 'Recent 2',
          releaseDate: '2026-02-15',
          isBlindBox: true,
          imageKey: 'recent_series_2',
        ),
      ],
      figures: const [],
    );
    final s1 = _seriesWithFigures(
      id: 's1',
      catalogTemplateId: 'recent_series',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      catalogTemplateId: 'recent_series_2',
      brandId: 'finding_unicorn',
      ipId: 'hirono',
      figures: [
        const ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2],
      figureStates: {'a': _owned('a')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      catalog: catalog,
      revealedAt: DateTime(2026, 5, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.trendChaser);
  });

  test('single-IP shelf does not become curator from memory alone', () {
    final s1 = _seriesWithFigures(
      id: 's1',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s3 = _seriesWithFigures(
      id: 's3',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'c',
          seriesId: 's3',
          name: 'C',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2, s3],
      figureStates: const {},
    );
    final memory = CollectionMemoryData(
      ipSeriesDepth: const {
        'baby_three': 1,
        'crybaby': 1,
        'nyota': 1,
        'nommi': 2,
        'pucky': 1,
        'maymei': 3,
        'the_monsters': 1,
        'zsiga': 1,
        'skullpanda': 1,
        'nanci': 2,
        'dora': 3,
        'sonny_angel': 3,
        'smiski': 8,
        'chicken_nihao': 2,
        'cc': 1,
        'twinkle_twinkle': 1,
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      memory: memory,
      revealedAt: DateTime(2026, 5, 29),
    );
    expect(identity.archetypeId, isNot(CollectorTypeArchetypeId.curator));
  });

  test('curator can win when current shelf has IP diversity', () {
    final s1 = _seriesWithFigures(
      id: 's1',
      brandId: 'pop_mart',
      ipId: 'the_monsters',
      catalogTemplateId: 'series_1',
      figures: const [
        ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      brandId: 'toptoy',
      ipId: 'hirono',
      catalogTemplateId: 'series_2',
      figures: const [
        ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2],
      figureStates: const {},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      memory: const CollectionMemoryData(ipSeriesDepth: {'smiski': 8}),
      revealedAt: DateTime(2026, 5, 29),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.curator);
  });

  test('Smiski-only shelf now resolves to loyalist', () {
    final s1 = _seriesWithFigures(
      id: 's1',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s3 = _seriesWithFigures(
      id: 's3',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'c',
          seriesId: 's3',
          name: 'C',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2, s3],
      figureStates: const {},
    );
    final memory = CollectionMemoryData(
      ipSeriesDepth: const {
        'baby_three': 1,
        'crybaby': 1,
        'nyota': 1,
        'nommi': 2,
        'pucky': 1,
        'maymei': 3,
        'the_monsters': 1,
        'zsiga': 1,
        'skullpanda': 1,
        'nanci': 2,
        'dora': 3,
        'sonny_angel': 3,
        'smiski': 8,
        'chicken_nihao': 2,
        'cc': 1,
        'twinkle_twinkle': 1,
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      memory: memory,
      revealedAt: DateTime(2026, 5, 29),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.loyalist);
  });
}
