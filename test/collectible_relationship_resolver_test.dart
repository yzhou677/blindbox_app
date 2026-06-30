import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as seed;
import 'package:blindbox_app/features/collectible_relationship/application/collectible_affinity_resolver.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_index.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_shelf_relationship_bridge.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_hint.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_kind.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfSeries _series({
  required String id,
  required String ipId,
  required String brandId,
  String? catalogTemplateId,
}) {
  return ShelfSeries(
    id: id,
    name: 'Series $id',
    brand: 'Brand',
    ipName: 'IP',
    figures: [
      ShelfFigure(
        id: 'f1',
        seriesId: id,
        name: 'A',
        rarity: 'common',
        isSecret: false,
        taxonomyIpId: ipId,
        taxonomyBrandId: brandId,
      ),
    ],
    shelfAccent: Colors.pink,
    catalogTemplateId: catalogTemplateId,
    taxonomyIpId: ipId,
    taxonomyBrandId: brandId,
  );
}

void main() {
  test('shelf companion when two series share IP', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        _series(id: 's1', ipId: 'ip_a', brandId: 'b1', catalogTemplateId: 'c1'),
        _series(id: 's2', ipId: 'ip_a', brandId: 'b1', catalogTemplateId: 'c2'),
      ],
      figureStates: const {},
    );
    final index = CollectibleRelationshipIndex.fromShelfAndCatalog(snap: snap);
    final hint = resolveCollectibleRelationshipHint(
      focal: const CollectibleRelationshipFocal(
        shelfSeriesId: 's1',
        taxonomyIpId: 'ip_a',
        taxonomyBrandId: 'b1',
      ),
      index: index,
    );
    expect(hint?.kind, CollectibleRelationshipKind.shelfCompanion);
    expect(hint?.relatedSeriesId, 's2');
  });

  test('analyzeCollectibleShelfRelationships caps at two', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        _series(id: 's1', ipId: 'ip_a', brandId: 'b1'),
        _series(id: 's2', ipId: 'ip_a', brandId: 'b1'),
        _series(id: 's3', ipId: 'ip_b', brandId: 'b1'),
        _series(id: 's4', ipId: 'ip_c', brandId: 'b1'),
      ],
      figureStates: const {},
    );
    final insights = analyzeCollectibleShelfRelationships(snap);
    expect(insights.length, lessThanOrEqualTo(2));
    expect(
      insights.any((i) => i.kind == ShelfRelationshipKind.sharedUniverse),
      isTrue,
    );
  });

  test('catalog neighbor when IP has off-shelf peer', () {
    final catalog = CatalogSeedBundle(
      brands: const [],
      ips: [
        const CatalogIp(id: 'ip_x', displayName: 'Dream World', brandId: 'b1'),
      ],
      series: [
        seed.CatalogSeries(
          id: 'cat_a',
          brandId: 'b1',
          ipId: 'ip_x',
          displayName: 'Alpha',
          releaseDate: null,
          isBlindBox: true,
          imageKey: 'cat_a',
        ),
        seed.CatalogSeries(
          id: 'cat_b',
          brandId: 'b1',
          ipId: 'ip_x',
          displayName: 'Beta',
          releaseDate: null,
          isBlindBox: true,
          imageKey: 'cat_b',
        ),
      ],
      figures: const [],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [
        _series(
          id: 's1',
          ipId: 'ip_x',
          brandId: 'b1',
          catalogTemplateId: 'cat_a',
        ),
      ],
      figureStates: const {},
    );
    final index = CollectibleRelationshipIndex.fromShelfAndCatalog(
      snap: snap,
      catalog: catalog,
    );
    final hint = resolveCollectibleRelationshipHint(
      focal: const CollectibleRelationshipFocal(
        catalogSeriesId: 'cat_a',
        taxonomyIpId: 'ip_x',
      ),
      index: index,
    );
    expect(hint?.kind, CollectibleRelationshipKind.catalogUniverseNeighbor);
    expect(hint?.relatedSeriesId, 'cat_b');
  });
}
