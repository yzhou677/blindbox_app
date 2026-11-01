import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_mapper.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Loads the catalog from canonical Firestore collections into [CatalogSeedBundle].
///
/// **Collections (flat, top-level only):** `brands`, `ips`, `series`, `figures`.
/// Sync cursor: `meta/catalog`. Schema: [FIRESTORE_CATALOG_SCHEMA.md].
///
/// Full load uses one-shot `.get()` per collection. Incremental load queries
/// `updatedAt > since` per collection (add/update only — catalog never deletes).
Future<CatalogSeedBundle> loadFirestoreCatalogBundle({
  FirebaseFirestore? firestore,
}) async {
  await CatalogImageResolver.ensureReady();
  await ensureFirebaseInitialized();
  final db = firestore ?? FirebaseFirestore.instance;

  final brandsSnap = db.collection('brands').get();
  final ipsSnap = db.collection('ips').get();
  final seriesSnap = db.collection('series').get();
  final figuresSnap = db.collection('figures').get();

  final results = await Future.wait([
    brandsSnap,
    ipsSnap,
    seriesSnap,
    figuresSnap,
  ]);

  return _bundleFromSnapshots(
    brandsSnap: results[0],
    ipsSnap: results[1],
    seriesSnap: results[2],
    figuresSnap: results[3],
  );
}

/// Reads `meta/catalog.lastUpdatedAt`, or null when missing / unreadable.
Future<DateTime?> loadCatalogMetaLastUpdatedAt({
  FirebaseFirestore? firestore,
}) async {
  await ensureFirebaseInitialized();
  final db = firestore ?? FirebaseFirestore.instance;
  final snap = await db.collection('meta').doc('catalog').get();
  if (!snap.exists) return null;
  final raw = snap.data()?['lastUpdatedAt'];
  if (raw is Timestamp) return raw.toDate().toUtc();
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

/// Changed documents since [since] (exclusive), as a partial [CatalogSeedBundle].
///
/// Empty lists mean no changes in that collection. Caller merges into the local
/// snapshot. Does not remove entities (catalog never deletes).
Future<CatalogSeedBundle> loadFirestoreCatalogDelta({
  required DateTime since,
  FirebaseFirestore? firestore,
}) async {
  await CatalogImageResolver.ensureReady();
  await ensureFirebaseInitialized();
  final db = firestore ?? FirebaseFirestore.instance;
  final cursor = Timestamp.fromDate(since.toUtc());

  final brandsSnap = db
      .collection('brands')
      .where('updatedAt', isGreaterThan: cursor)
      .get();
  final ipsSnap = db
      .collection('ips')
      .where('updatedAt', isGreaterThan: cursor)
      .get();
  final seriesSnap = db
      .collection('series')
      .where('updatedAt', isGreaterThan: cursor)
      .get();
  final figuresSnap = db
      .collection('figures')
      .where('updatedAt', isGreaterThan: cursor)
      .get();

  final results = await Future.wait([
    brandsSnap,
    ipsSnap,
    seriesSnap,
    figuresSnap,
  ]);

  return _bundleFromSnapshots(
    brandsSnap: results[0],
    ipsSnap: results[1],
    seriesSnap: results[2],
    figuresSnap: results[3],
  );
}

CatalogSeedBundle _bundleFromSnapshots({
  required QuerySnapshot<Map<String, dynamic>> brandsSnap,
  required QuerySnapshot<Map<String, dynamic>> ipsSnap,
  required QuerySnapshot<Map<String, dynamic>> seriesSnap,
  required QuerySnapshot<Map<String, dynamic>> figuresSnap,
}) {
  final brands = _mapBrands(brandsSnap);
  final ips = _mapIps(ipsSnap);
  final series = _mapSeries(seriesSnap);
  final figures = _mapFigures(figuresSnap);

  brands.sort((a, b) => a.id.compareTo(b.id));
  ips.sort((a, b) => a.id.compareTo(b.id));
  figures.sort((a, b) => a.id.compareTo(b.id));

  return CatalogSeedBundle(
    brands: brands,
    ips: ips,
    series: series,
    figures: figures,
  );
}

List<CatalogBrand> _mapBrands(QuerySnapshot<Map<String, dynamic>> snap) {
  final out = <CatalogBrand>[];
  for (final doc in snap.docs) {
    final mapped = mapFirestoreBrand(doc.id, doc.data());
    if (mapped != null) out.add(mapped);
  }
  return out;
}

List<CatalogIp> _mapIps(QuerySnapshot<Map<String, dynamic>> snap) {
  final out = <CatalogIp>[];
  for (final doc in snap.docs) {
    final mapped = mapFirestoreIp(doc.id, doc.data());
    if (mapped != null) out.add(mapped);
  }
  return out;
}

List<CatalogSeries> _mapSeries(QuerySnapshot<Map<String, dynamic>> snap) {
  final out = <({int docOrder, CatalogSeries series})>[];
  for (var i = 0; i < snap.docs.length; i++) {
    final doc = snap.docs[i];
    final mapped = mapFirestoreSeries(doc.id, doc.data());
    if (mapped != null) out.add((docOrder: i, series: mapped));
  }
  out.sort(
    (a, b) =>
        _compareSeriesSnapshotOrder(a.series, b.series, a.docOrder, b.docOrder),
  );
  return [for (final e in out) e.series];
}

int _compareSeriesSnapshotOrder(
  CatalogSeries a,
  CatalogSeries b, [
  int? orderA,
  int? orderB,
]) {
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
  if (orderA != null && orderB != null) {
    return orderB.compareTo(orderA);
  }
  return b.id.compareTo(a.id);
}

List<CatalogFigure> _mapFigures(QuerySnapshot<Map<String, dynamic>> snap) {
  final out = <CatalogFigure>[];
  for (final doc in snap.docs) {
    final mapped = mapFirestoreFigure(doc.id, doc.data());
    if (mapped != null) out.add(mapped);
  }
  return out;
}
