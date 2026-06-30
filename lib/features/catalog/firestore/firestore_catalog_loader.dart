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
/// Schema: [FIRESTORE_CATALOG_SCHEMA.md]. Storage paths: [FIREBASE_STORAGE_CATALOG.md].
///
/// One-shot `.get()` per collection (no listeners).
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

  final results = await Future.wait([brandsSnap, ipsSnap, seriesSnap, figuresSnap]);

  final brands = _mapBrands(results[0]);
  final ips = _mapIps(results[1]);
  final series = _mapSeries(results[2]);
  final figures = _mapFigures(results[3]);

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
  out.sort((a, b) => _compareSeriesSnapshotOrder(a.series, b.series, a.docOrder, b.docOrder));
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
