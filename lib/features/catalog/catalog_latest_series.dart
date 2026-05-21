import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Picks up to [limit] series not already on shelf, newest releaseDate first.
List<catalog.CatalogSeries> pickLatestSeriesRecommendations(
  CatalogSeedBundle bundle,
  CollectionSnapshot snap, {
  int limit = 5,
}) {
  final orderIndex = <String, int>{
    for (var i = 0; i < bundle.series.length; i++) bundle.series[i].id: i,
  };

  final candidates = bundle.series
      .where((s) => !snap.hasTemplateOnShelf(s.id))
      .toList(growable: false);
  candidates.sort((a, b) => _compareNewestFirst(a, b, orderIndex));
  return candidates.take(limit).toList(growable: false);
}

int _compareNewestFirst(
  catalog.CatalogSeries a,
  catalog.CatalogSeries b,
  Map<String, int> orderIndex,
) {
  final da = a.releaseDate;
  final db = b.releaseDate;
  if (da != null && db != null) {
    final byDate = db.compareTo(da);
    if (byDate != 0) return byDate;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  final ia = orderIndex[a.id] ?? 0;
  final ib = orderIndex[b.id] ?? 0;
  return ib.compareTo(ia);
}
