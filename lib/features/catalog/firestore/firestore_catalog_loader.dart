import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_mapper.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Loads the collectible catalog universe from Firestore into [CatalogSeedBundle].
///
/// Does **not** replace [loadCatalogSeedBundle] — local JSON remains the default
/// for tests, offline seed, and dev fallback until you wire a source switch.
///
/// Schema: see [FIRESTORE_CATALOG_SCHEMA.md] in this directory.
///
/// - No realtime listeners, caching, or sync — one-shot reads per collection.
/// - Injects [FirebaseFirestore] for tests; defaults to [FirebaseFirestore.instance].
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
  series.sort((a, b) => a.id.compareTo(b.id));
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
  final out = <CatalogSeries>[];
  for (final doc in snap.docs) {
    final mapped = mapFirestoreSeries(doc.id, doc.data());
    if (mapped != null) out.add(mapped);
  }
  return out;
}

List<CatalogFigure> _mapFigures(QuerySnapshot<Map<String, dynamic>> snap) {
  final out = <CatalogFigure>[];
  for (final doc in snap.docs) {
    final mapped = mapFirestoreFigure(doc.id, doc.data());
    if (mapped != null) out.add(mapped);
  }
  return out;
}
