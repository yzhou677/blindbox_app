import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_loader.dart';

/// Loads the catalog: canonical Firestore (`brands`, `ips`, `series`, `figures`) first,
/// bundled seed JSON on failure. See `firestore/FIRESTORE_CATALOG_SCHEMA.md`.
Future<CatalogSeedBundle> loadCatalogBundle() async {
  try {
    return await loadFirestoreCatalogBundle();
  } catch (_) {
    return loadCatalogSeedBundle();
  }
}
