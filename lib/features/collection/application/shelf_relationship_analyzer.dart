import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';

const int _maxInsights = 2;

List<ShelfRelationshipInsight> analyzeShelfRelationships(
  CollectionSnapshot snap,
) {
  if (snap.shelfSeries.length < 2) return const [];

  final out = <ShelfRelationshipInsight>[];

  final byIp = <String, List<ShelfSeries>>{};
  for (final series in snap.shelfSeries) {
    final ip = series.taxonomyIpId?.trim();
    if (ip == null || ip.isEmpty) continue;
    byIp.putIfAbsent(ip, () => []).add(series);
  }

  for (final entry in byIp.entries) {
    if (entry.value.length < 2) continue;
    final primary = entry.value.first;
    final related = entry.value[1];
    out.add(
      ShelfRelationshipInsight(
        kind: ShelfRelationshipKind.sharedUniverse,
        primarySeriesId: primary.id,
        relatedSeriesId: related.id,
        taxonomyIpId: entry.key,
      ),
    );
    if (out.length >= _maxInsights) return out;
  }

  final byBrand = <String, List<ShelfSeries>>{};
  for (final series in snap.shelfSeries) {
    final brand = series.taxonomyBrandId?.trim();
    if (brand == null || brand.isEmpty) continue;
    byBrand.putIfAbsent(brand, () => []).add(series);
  }

  for (final brandEntry in byBrand.entries) {
    final ips = <String, List<ShelfSeries>>{};
    for (final s in brandEntry.value) {
      final ip = s.taxonomyIpId?.trim();
      if (ip == null || ip.isEmpty) continue;
      ips.putIfAbsent(ip, () => []).add(s);
    }
    if (ips.length < 2) continue;
    final ipLists = ips.values.where((list) => list.length >= 2).toList();
    if (ipLists.length < 2) continue;
    final a = ipLists[0].first;
    final b = ipLists[1].first;
    out.add(
      ShelfRelationshipInsight(
        kind: ShelfRelationshipKind.complementaryMood,
        primarySeriesId: a.id,
        relatedSeriesId: b.id,
        taxonomyBrandId: brandEntry.key,
      ),
    );
    if (out.length >= _maxInsights) return out;
  }

  return out;
}
