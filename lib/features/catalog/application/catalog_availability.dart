import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-visible catalog availability for catalog-powered surfaces.
enum CatalogAvailabilityUiState {
  /// First fetch / bootstrap placeholder — catalog not ready yet.
  loading,

  /// No usable catalog (e.g. first launch offline after sync, resolved empty).
  offlineFirstLaunch,

  /// Catalog-ready; normal browse/search behavior.
  ready,
}

/// Derived UI snapshot — do not read [CatalogBundleCache] from widgets directly.
class CatalogAvailability {
  const CatalogAvailability(this.state);

  final CatalogAvailabilityUiState state;

  bool get isCatalogUsable => state == CatalogAvailabilityUiState.ready;

  bool get isLoading =>
      state == CatalogAvailabilityUiState.loading;

  bool get isOfflineFirstLaunch =>
      state == CatalogAvailabilityUiState.offlineFirstLaunch;
}

CatalogAvailability _resolveCatalogAvailability({
  required AsyncValue<dynamic> bundleAsync,
  required CatalogBundleMemoryOrigin origin,
  required bool isCatalogReady,
}) {
  if (!isCatalogReady) {
    if (bundleAsync.hasError) {
      return const CatalogAvailability(CatalogAvailabilityUiState.offlineFirstLaunch);
    }
    return const CatalogAvailability(CatalogAvailabilityUiState.loading);
  }

  if (bundleAsync.hasError) {
    return const CatalogAvailability(CatalogAvailabilityUiState.offlineFirstLaunch);
  }

  if (origin == CatalogBundleMemoryOrigin.resolved) {
    final bundle = CatalogBundleCache.current;
    final empty = bundle == null ||
        (bundle.series.isEmpty &&
            bundle.figures.isEmpty &&
            bundle.brands.isEmpty);
    if (empty) {
      return const CatalogAvailability(CatalogAvailabilityUiState.offlineFirstLaunch);
    }
  }

  // Usable catalog — background Firestore refresh must not regress to loading UI.
  return const CatalogAvailability(CatalogAvailabilityUiState.ready);
}

/// Single source for catalog loading / offline / refresh UI state.
final catalogAvailabilityProvider = Provider<CatalogAvailability>((ref) {
  ref.watch(catalogBundleRevisionProvider);
  final bundleAsync = ref.watch(catalogBundleProvider);
  return _resolveCatalogAvailability(
    bundleAsync: bundleAsync,
    origin: CatalogBundleCache.memoryOrigin,
    isCatalogReady: CatalogBundleCache.isCatalogReady,
  );
});

/// Retries catalog download after offline / failed first launch.
final catalogDownloadRetryProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final outcome = await CatalogBundleCache.refreshFromFirestore(force: true);
    if (outcome != CatalogFirestoreRefreshResult.refreshed) {
      ref.invalidate(catalogBundleProvider);
    }
  };
});
