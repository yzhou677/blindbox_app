import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';

/// Loads catalog metadata via [CatalogBundleCache] (deduped, in-memory).
///
/// At app start prefer [CatalogBundleCache.loadOfflineFirst] for seed-first paint.
/// Firestore is tried with timeout, then bundled `tools/seed/` fallback.
Future<CatalogSeedBundle> loadCatalogBundle() => CatalogBundleCache.getOrLoad();
