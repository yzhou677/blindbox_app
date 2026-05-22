import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_index.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';

const int _maxShelfInsights = 2;

/// Shelf-only pairwise insights (Phase 4 shape; shared taxonomy rules).
List<ShelfRelationshipInsight> analyzeCollectibleShelfRelationships(
  CollectionSnapshot snap,
) {
  if (snap.shelfSeries.length < 2) return const [];

  final index = CollectibleRelationshipIndex.fromShelfAndCatalog(snap: snap);
  final out = <ShelfRelationshipInsight>[];

  for (final entry in index.shelfSeriesIdsByIp.entries) {
    if (entry.value.length < 2) continue;
    final primary = entry.value.first;
    final related = entry.value[1];
    out.add(
      ShelfRelationshipInsight(
        kind: ShelfRelationshipKind.sharedUniverse,
        primarySeriesId: primary,
        relatedSeriesId: related,
        taxonomyIpId: entry.key,
      ),
    );
    if (out.length >= _maxShelfInsights) return out;
  }

  for (final brandEntry in index.shelfIpsByBrand.entries) {
    if (brandEntry.value.length < 2) continue;
    final ipLists = <List<String>>[];
    for (final ip in brandEntry.value) {
      final series = index.shelfSeriesIdsByIp[ip];
      if (series != null && series.length >= 2) {
        ipLists.add(series);
      }
    }
    if (ipLists.length < 2) {
      final ips = brandEntry.value.toList()..sort();
      if (ips.length < 2) continue;
      final aList = index.shelfSeriesIdsByIp[ips[0]];
      final bList = index.shelfSeriesIdsByIp[ips[1]];
      if (aList == null || bList == null) continue;
      out.add(
        ShelfRelationshipInsight(
          kind: ShelfRelationshipKind.complementaryMood,
          primarySeriesId: aList.first,
          relatedSeriesId: bList.first,
          taxonomyBrandId: brandEntry.key,
        ),
      );
      if (out.length >= _maxShelfInsights) return out;
      continue;
    }
    final a = ipLists[0].first;
    final b = ipLists[1].first;
    out.add(
      ShelfRelationshipInsight(
        kind: ShelfRelationshipKind.complementaryMood,
        primarySeriesId: a,
        relatedSeriesId: b,
        taxonomyBrandId: brandEntry.key,
      ),
    );
    if (out.length >= _maxShelfInsights) return out;
  }

  return out;
}
