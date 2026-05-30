import 'package:blindbox_app/features/collection/application/collection_series_identity.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionSnapshot _snapshotWithSeries(List<ShelfSeries> shelfSeries) {
  return CollectionSnapshot(shelfSeries: shelfSeries, figureStates: const {});
}

ShelfSeries _series({
  required String id,
  required String name,
  required String brand,
  String? catalogTemplateId,
  String? taxonomyBrandId,
  String? taxonomyIpId,
}) {
  return ShelfSeries(
    id: id,
    name: name,
    brand: brand,
    ipName: 'ip',
    figures: const [
      ShelfFigure(
        id: 'f1',
        seriesId: 's1',
        name: 'fig',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: const Color(0xFFE8DEF5),
    catalogTemplateId: catalogTemplateId,
    taxonomyBrandId: taxonomyBrandId,
    taxonomyIpId: taxonomyIpId,
  );
}

void main() {
  group('exact template / drop id', () {
    test('catalog-backed exact template match is owned', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 's1',
          name: 'Any',
          brand: 'Any',
          catalogTemplateId: 'drop-the_monsters_v3',
        ),
      ]);
      final match = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'drop-the_monsters_v3',
        seriesName: 'Whatever',
        brandName: 'Whatever',
      );
      expect(match.owned, isTrue);
      expect(
        match.kind,
        CollectionSeriesOwnershipMatchKind.exactCatalogTemplate,
      );
      expect(match.removableViaReleaseCta, isTrue);
    });

    test('alternate catalog template id also matches exact ownership', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 's1',
          name: 'Any',
          brand: 'Any',
          catalogTemplateId: 'where_moments_meet',
        ),
      ]);
      final match = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'drop-where_moments_meet',
        alternateCatalogTemplateIds: const ['where_moments_meet'],
        seriesName: 'Where Moments Meet Series Plush Doll',
        brandName: 'Nyota',
      );
      expect(match.owned, isTrue);
      expect(
        match.kind,
        CollectionSeriesOwnershipMatchKind.exactCatalogTemplate,
      );
      expect(match.matchedCatalogTemplateId, 'where_moments_meet');
    });
  });

  group('canonical brand + series (custom / display drift)', () {
    test('canonicalized brand+series match detects custom user entry', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 'custom_1',
          name: 'Crybaby - Ocean',
          brand: 'POP MART',
          catalogTemplateId: null,
        ),
      ]);
      final match = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'drop-crybaby-ocean',
        seriesName: 'Crybaby_Ocean',
        brandName: 'popmart',
      );
      expect(match.owned, isTrue);
      expect(
        match.kind,
        CollectionSeriesOwnershipMatchKind.canonicalBrandSeries,
      );
      expect(match.removableViaReleaseCta, isFalse);
    });

    test('unmatched custom entry returns not owned', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 'custom_1',
          name: 'Spring Picnic customs',
          brand: 'Local Artist',
          catalogTemplateId: null,
        ),
      ]);
      final match = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'drop-hirono-other-one',
        seriesName: 'The Other One',
        brandName: 'POP MART',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'hirono',
      );
      expect(match.owned, isFalse);
      expect(match.kind, isNull);
    });
  });

  group('taxonomy / universe must NOT imply ownership', () {
    test('same taxonomy brand+ip, different series → NOT owned', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 'shelf-pinky',
          name: 'Pinky Energy Series',
          brand: 'TOP TOY',
          catalogTemplateId: 'pinky_energy_series',
          taxonomyBrandId: 'top_toy',
          taxonomyIpId: 'nommi',
        ),
      ]);

      final magicalChristmas = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'magical_christmas_eve_series',
        seriesName: 'Magical Christmas Eve Series',
        brandName: 'TOP TOY',
        taxonomyBrandId: 'top_toy',
        taxonomyIpId: 'nommi',
      );
      expect(magicalChristmas.owned, isFalse);

      final entwinedFate = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'entwined_fate_series',
        seriesName: 'Entwined Fate Series',
        brandName: 'TOP TOY',
        taxonomyBrandId: 'top_toy',
        taxonomyIpId: 'nommi',
      );
      expect(entwinedFate.owned, isFalse);
    });

    test('same brand display, different series → NOT owned', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 'shelf-a',
          name: 'Pinky Energy Series',
          brand: 'TOP TOY',
          catalogTemplateId: 'pinky_energy_series',
        ),
      ]);

      final match = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'other_series_id',
        seriesName: 'Magical Christmas Eve Series',
        brandName: 'TOP TOY',
      );
      expect(match.owned, isFalse);
    });

    test('taxonomy-only shelf row does not mark unrelated catalog series owned', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 's1',
          name: 'Unrelated shelf label',
          brand: 'Other',
          taxonomyBrandId: 'POP_MART',
          taxonomyIpId: 'THE_MONSTERS',
        ),
      ]);
      final match = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'drop-other',
        seriesName: 'Different Series Name',
        brandName: 'Different Brand',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'the_monsters',
      );
      expect(match.owned, isFalse);
      expect(match.kind, isNull);
    });
  });

  group('exact series in same universe stays owned', () {
    test('owned catalog series matches by template id', () {
      final snap = _snapshotWithSeries([
        _series(
          id: 'shelf-pinky',
          name: 'Pinky Energy Series',
          brand: 'TOP TOY',
          catalogTemplateId: 'pinky_energy_series',
          taxonomyBrandId: 'top_toy',
          taxonomyIpId: 'nommi',
        ),
      ]);

      final match = resolveCollectionSeriesOwnership(
        snapshot: snap,
        catalogTemplateId: 'drop-pinky_energy_series',
        alternateCatalogTemplateIds: const ['pinky_energy_series'],
        seriesName: 'Pinky Energy Series',
        brandName: 'TOP TOY',
        taxonomyBrandId: 'top_toy',
        taxonomyIpId: 'nommi',
      );
      expect(match.owned, isTrue);
      expect(
        match.kind,
        CollectionSeriesOwnershipMatchKind.exactCatalogTemplate,
      );
    });
  });

  test('canonicalization normalizes spaces/underscores/hyphens/punctuation', () {
    expect(canonicalizeCollectionIdentity('POP MART'), 'popmart');
    expect(canonicalizeCollectionIdentity('THE_MONSTERS'), 'themonsters');
    expect(canonicalizeCollectionIdentity('Crybaby - Ocean'), 'crybabyocean');
    expect(canonicalizeCollectionIdentity('  Crybaby/Ocean!  '), 'crybabyocean');
  });
}
