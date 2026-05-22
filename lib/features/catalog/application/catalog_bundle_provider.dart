import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared catalog metadata for Home, Add Series, and taxonomy — one load per session.
final catalogBundleProvider = FutureProvider<CatalogSeedBundle>((ref) async {
  return CatalogBundleCache.getOrLoad();
});
