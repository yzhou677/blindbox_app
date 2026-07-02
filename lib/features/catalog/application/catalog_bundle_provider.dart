import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumps when [CatalogBundleCache] commits a replacement bundle in memory.
///
/// Watched by [catalogBundleProvider] so dependents rebuild declaratively.
final catalogBundleRevisionProvider =
    NotifierProvider<CatalogBundleRevisionNotifier, int>(
  CatalogBundleRevisionNotifier.new,
);

class CatalogBundleRevisionNotifier extends Notifier<int> {
  void Function()? _removeBundleListener;
  void Function()? _removeRefreshListener;

  @override
  int build() {
    _removeBundleListener?.call();
    _removeRefreshListener?.call();
    _removeBundleListener =
        CatalogBundleCache.addBundleReplacedListener(_bumpRevision);
    _removeRefreshListener =
        CatalogBundleCache.addRefreshStateListener(_bumpRevision);
    ref.onDispose(() {
      _removeBundleListener?.call();
      _removeRefreshListener?.call();
      _removeBundleListener = null;
      _removeRefreshListener = null;
    });
    return 0;
  }

  void _bumpRevision() {
    final bundle = CatalogBundleCache.current;
    if (bundle != null) {
      MarketCatalogIdentityCache.install(bundle);
    }
    state = state + 1;
  }
}

/// Shared catalog metadata —reloads when the in-memory bundle is replaced.
final catalogBundleProvider = FutureProvider<CatalogSeedBundle>((ref) async {
  ref.watch(catalogBundleRevisionProvider);
  final bundle = await CatalogBundleCache.getOrLoad();
  MarketCatalogIdentityCache.install(bundle);
  return bundle;
});

/// Synchronous catalog bundle for local search — matches Discover semantics without
/// waiting on [catalogBundleProvider] when [CatalogBundleCache] is already ready.
CatalogSeedBundle? resolveCatalogBundleForSearch({
  CatalogSeedBundle? providerBundle,
}) {
  if (providerBundle != null) return providerBundle;
  if (CatalogBundleCache.isCatalogReady) {
    return CatalogBundleCache.current;
  }
  return null;
}

/// Catalog search over the current bundle; recreated when [catalogBundleProvider]
/// updates.
final catalogSearchServiceProvider = Provider<CatalogSearchService?>((ref) {
  ref.watch(catalogBundleRevisionProvider);
  final catalog = resolveCatalogBundleForSearch(
    providerBundle: ref.watch(catalogBundleProvider).valueOrNull,
  );
  if (catalog == null) return null;
  return CatalogSearchService(catalog);
});
