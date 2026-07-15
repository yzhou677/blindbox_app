import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_index.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_hint.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_kind.dart';
import 'package:blindbox_app/features/collectible_relationship/presentation/collectible_relationship_copy.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shelf companion copy uses peer series name', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 'a',
          name: 'Dreamy Pastel',
          brand: 'B',
          ipName: 'IP',
          figures: const [],
          shelfAccent: Colors.pink,
          taxonomyIpId: 'ip1',
        ),
        ShelfSeries(
          id: 'b',
          name: 'Soft Night',
          brand: 'B',
          ipName: 'IP',
          figures: const [],
          shelfAccent: Colors.blue,
          taxonomyIpId: 'ip1',
        ),
      ],
      figureStates: const {},
    );
    final index = CollectibleRelationshipIndex.fromShelfAndCatalog(snap: snap);
    final line = CollectibleRelationshipCopy.lineForHint(
      hint: const CollectibleRelationshipHint(
        kind: CollectibleRelationshipKind.shelfCompanion,
        relatedSeriesId: 'b',
        focalSeriesId: 'a',
      ),
      index: index,
    );
    expect(line, contains('Soft Night'));
    expect(line, isNot(contains('recommend')));
  });

  test('catalog neighbor copy uses factual taxonomy wording', () {
    const index = CollectibleRelationshipIndex(
      shelfSeriesIds: {},
      shelfSeriesById: {},
      shelfSeriesIdsByIp: {},
      shelfIpsByBrand: {},
      catalogSeriesIdsByIp: {},
      catalogSeriesNameById: {},
      lineupFiguresByCatalogSeriesId: {},
      catalogIpNameById: {'dimoo': 'DIMOO'},
    );
    final line = CollectibleRelationshipCopy.lineForHint(
      hint: const CollectibleRelationshipHint(
        kind: CollectibleRelationshipKind.catalogUniverseNeighbor,
        taxonomyIpId: 'dimoo',
      ),
      index: index,
    );

    expect(line, 'Part of the DIMOO catalog universe');
    expect(line, isNot(contains('Nearby in the quiet')));
  });

  test('catalog neighbor copy stays empty without catalog facts', () {
    const index = CollectibleRelationshipIndex(
      shelfSeriesIds: {},
      shelfSeriesById: {},
      shelfSeriesIdsByIp: {},
      shelfIpsByBrand: {},
      catalogSeriesIdsByIp: {},
      catalogSeriesNameById: {},
      lineupFiguresByCatalogSeriesId: {},
      catalogIpNameById: {},
    );
    final line = CollectibleRelationshipCopy.lineForHint(
      hint: const CollectibleRelationshipHint(
        kind: CollectibleRelationshipKind.catalogUniverseNeighbor,
      ),
      index: index,
    );

    expect(line, isNull);
  });
}
