import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';

/// Upserts [delta] entities into [base] by canonical id (add + update only).
///
/// Catalog never soft-deletes; omitted ids in [delta] are left unchanged.
CatalogSeedBundle mergeCatalogSeedBundle(
  CatalogSeedBundle base,
  CatalogSeedBundle delta,
) {
  return CatalogSeedBundle(
    brands: _upsertById(base.brands, delta.brands, (b) => b.id)
      ..sort((a, b) => a.id.compareTo(b.id)),
    ips: _upsertById(base.ips, delta.ips, (ip) => ip.id)
      ..sort((a, b) => a.id.compareTo(b.id)),
    series: _upsertById(base.series, delta.series, (s) => s.id)
      ..sort(_compareSeries),
    figures: _upsertById(base.figures, delta.figures, (f) => f.id)
      ..sort((a, b) => a.id.compareTo(b.id)),
  );
}

List<T> _upsertById<T>(
  List<T> base,
  List<T> delta,
  String Function(T item) idOf,
) {
  if (delta.isEmpty) return List<T>.from(base);
  final map = <String, T>{for (final item in base) idOf(item): item};
  for (final item in delta) {
    map[idOf(item)] = item;
  }
  return map.values.toList();
}

int _compareSeries(CatalogSeries a, CatalogSeries b) {
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
  return b.id.compareTo(a.id);
}
