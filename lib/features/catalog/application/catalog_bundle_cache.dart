import 'dart:async';

import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_persistence.dart';
import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_loader.dart';
import 'package:flutter/foundation.dart';

enum CatalogBundleLoadSource {
  /// In-memory bundle reused within the same process (e.g. second call).
  memory,

  /// Last successful Firestore snapshot from on-device persistence.
  persisted,

  /// Bundled `tools/seed/` — first install or never synced.
  seed,

  /// Synced before but no valid persisted snapshot (corrupt / missing file).
  empty,
}

enum CatalogFirestoreRefreshResult {
  refreshed,
  skippedWithinTtl,
  failed,
}

/// In-memory provenance for [_bundle] inside [CatalogBundleCache].
///
/// Single source of truth for catalog readiness — replaces a parallel placeholder
/// flag. [bootstrapPlaceholder] is the only non-ready state with a memory slot.
enum CatalogBundleMemoryOrigin {
  /// No bundle in memory.
  none,

  /// [loadOfflineFirst] empty bootstrap — [getOrLoad] must await refresh/load.
  bootstrapPlaceholder,

  /// Bundled `tools/seed/`.
  seed,

  /// On-disk Firestore snapshot.
  persisted,

  /// Successful Firestore fetch (background refresh or [getOrLoad] network path).
  firestore,

  /// Refresh/load fallbacks exhausted; bundle may still be empty lists.
  resolved;

  bool get isCatalogReady =>
      this != none && this != CatalogBundleMemoryOrigin.bootstrapPlaceholder;
}

/// In-memory catalog snapshot — static metadata only (no Storage URLs).
///
/// **Offline-first startup:** persisted Firestore snapshot (when available) →
/// bundled seed (first install / never synced) → empty bootstrap placeholder →
/// background Firestore refresh. After the first successful refresh, persisted
/// data is authoritative on cold start; deleted Firestore entries do not
/// reappear from seed.
///
/// **Readiness vs memory slot**
///
/// [_bundle] plus [CatalogBundleMemoryOrigin] track provenance. Only
/// [CatalogBundleMemoryOrigin.bootstrapPlaceholder] is a non-ready memory
/// slot: [getOrLoad] awaits startup Firestore refresh (or the shared network
/// load) instead of returning the empty bundle immediately.
///
/// **State machine (what callers receive)**
///
/// | [CatalogBundleMemoryOrigin] | [loadOfflineFirst] | [getOrLoad] |
/// |-------|-------------------|-------------|
/// | `persisted` | Returns disk snapshot; background refresh | Returns immediately |
/// | `seed` | Returns seed; background refresh | Returns immediately |
/// | `bootstrapPlaceholder` | Returns empty; background refresh | Awaits refresh / shared load |
/// | `firestore` | Returns memory bundle | Returns immediately |
/// | `resolved` | Returns empty (load exhausted) | Returns empty (no duplicate fetch) |
///
/// **Refresh policy**
///
/// - Successful refreshes are throttled for 5 minutes.
/// - Failed refreshes never update the TTL.
/// - Concurrent refreshes share one in-flight [Future].
/// - [refreshFromFirestore] `force: true` bypasses the TTL.
abstract final class CatalogBundleCache {
  static const Duration firestoreTimeout = Duration(seconds: 12);
  static const Duration catalogRefreshTtl = Duration(minutes: 5);

  static CatalogSeedBundle? _bundle;
  static CatalogBundleMemoryOrigin _memoryOrigin = CatalogBundleMemoryOrigin.none;

  static Future<CatalogSeedBundle>? _inFlight;
  static Future<CatalogFirestoreRefreshResult>? _refreshInFlight;
  static DateTime? _lastFirestoreRefreshAt;

  static CatalogSeedBundle? get current => _bundle;

  /// Provenance of the in-memory bundle (debug / tests).
  static CatalogBundleMemoryOrigin get memoryOrigin => _memoryOrigin;

  /// Whether [_bundle] is non-null (includes bootstrap placeholders).
  static bool get hasValue => _bundle != null;

  /// Whether [_bundle] is safe to treat as a completed catalog load.
  static bool get isCatalogReady => _memoryOrigin.isCatalogReady && _bundle != null;

  /// Whether a background Firestore refresh is in flight (UI hint only).
  static bool get isRefreshInFlight => _refreshInFlight != null;

  @visibleForTesting
  static CatalogBundleMemoryOrigin get memoryOriginForTest => _memoryOrigin;

  @visibleForTesting
  static DateTime? get lastFirestoreRefreshAt => _lastFirestoreRefreshAt;

  @visibleForTesting
  static void setLastFirestoreRefreshAtForTest(DateTime? at) {
    _lastFirestoreRefreshAt = at;
  }

  static bool _isWithinRefreshTtl(DateTime now) {
    final last = _lastFirestoreRefreshAt;
    if (last == null) return false;
    return now.difference(last) < catalogRefreshTtl;
  }

  /// Startup source for the current in-memory bundle (debug / tests).
  static CatalogBundleLoadSource? lastStartupSource;

  @visibleForTesting
  static Future<CatalogSeedBundle> Function()? loadSeedOverride;

  @visibleForTesting
  static Future<CatalogSeedBundle> Function()? loadFirestoreOverride;

  @visibleForTesting
  static Future<CatalogSeedBundle?> Function()? loadPersistedOverride;

  @visibleForTesting
  static Future<void> Function(CatalogSeedBundle bundle)? persistOverride;

  @visibleForTesting
  static Future<bool> Function()? hasCompletedFirestoreSyncOverride;

  static void prime(CatalogSeedBundle bundle) {
    _setMemoryBundle(bundle, CatalogBundleMemoryOrigin.firestore);
  }

  /// Non-ready bootstrap slot without starting a background Firestore refresh.
  @visibleForTesting
  static void primeBootstrapPlaceholderForTest() {
    _setMemoryBundle(_emptyBundle(), CatalogBundleMemoryOrigin.bootstrapPlaceholder);
  }

  static void _setMemoryBundle(
    CatalogSeedBundle bundle,
    CatalogBundleMemoryOrigin origin,
  ) {
    _bundle = bundle;
    _memoryOrigin = origin;
  }

  static void _clearMemoryBundle() {
    _bundle = null;
    _memoryOrigin = CatalogBundleMemoryOrigin.none;
  }

  /// Optional hook after a successful Firestore refresh replaces [_bundle].
  ///
  /// Registered by [CatalogBundleRefreshBridge] to invalidate Discover feed.
  static void Function()? onBundleReplaced;

  static final List<void Function()> _bundleReplacedListeners = [];

  /// Registers [listener] for successful in-memory bundle replacements.
  ///
  /// Returns a dispose callback. Listeners must not throw.
  static void Function() addBundleReplacedListener(void Function() listener) {
    _bundleReplacedListeners.add(listener);
    return () {
      _bundleReplacedListeners.remove(listener);
    };
  }

  @visibleForTesting
  static int get bundleReplacedListenerCountForTest =>
      _bundleReplacedListeners.length;

  static void _notifyBundleReplaced() {
    onBundleReplaced?.call();
    for (final listener in List<void Function()>.of(_bundleReplacedListeners)) {
      listener();
    }
  }

  @visibleForTesting
  static void triggerBundleReplacedForTest() => _notifyBundleReplaced();

  @visibleForTesting
  static void resetForTest() {
    _clearMemoryBundle();
    _inFlight = null;
    _refreshInFlight = null;
    _lastFirestoreRefreshAt = null;
    onBundleReplaced = null;
    _bundleReplacedListeners.clear();
    loadSeedOverride = null;
    loadFirestoreOverride = null;
    loadPersistedOverride = null;
    persistOverride = null;
    hasCompletedFirestoreSyncOverride = null;
    lastStartupSource = null;
  }

  /// Persisted snapshot → bundled seed (never synced) → background refresh.
  static Future<CatalogSeedBundle> loadOfflineFirst() async {
    if (_bundle != null) {
      _logStartup(CatalogBundleLoadSource.memory, _bundle!);
      unawaited(refreshFromFirestore());
      return _bundle!;
    }

    final local = await _loadLocalCatalog();
    if (local != null) {
      _setMemoryBundle(local, CatalogBundleMemoryOrigin.persisted);
      _logStartup(CatalogBundleLoadSource.persisted, local);
      unawaited(refreshFromFirestore());
      return local;
    }

    if (!await _hasCompletedFirestoreSync()) {
      final seed = await _loadSeed();
      _setMemoryBundle(seed, CatalogBundleMemoryOrigin.seed);
      _logStartup(CatalogBundleLoadSource.seed, seed);
      unawaited(refreshFromFirestore());
      return seed;
    }

    final empty = _emptyBundle();
    _setMemoryBundle(empty, CatalogBundleMemoryOrigin.bootstrapPlaceholder);
    _logStartup(CatalogBundleLoadSource.empty, empty);
    unawaited(refreshFromFirestore());
    return empty;
  }

  /// Returns a catalog-ready bundle or loads once (deduped).
  ///
  /// Prefer [loadOfflineFirst] at startup for offline-first paint. Does not
  /// return a bootstrap placeholder without awaiting startup refresh or the
  /// shared network load path.
  static Future<CatalogSeedBundle> getOrLoad() async {
    if (isCatalogReady) {
      return _bundle!;
    }

    if (_memoryOrigin == CatalogBundleMemoryOrigin.bootstrapPlaceholder) {
      final refreshPending = _refreshInFlight;
      if (refreshPending != null) {
        await refreshPending;
      }
      if (isCatalogReady) {
        return _bundle!;
      }
      // Startup refresh was TTL-skipped or never started; fall through to the
      // shared network load without returning the placeholder early.
    }

    final pending = _inFlight;
    if (pending != null) return pending;

    final load = _loadNetworkThenPersistedOrSeed();
    _inFlight = load;
    try {
      return await load;
    } finally {
      if (identical(_inFlight, load)) _inFlight = null;
    }
  }

  /// Stale-while-revalidate: updates [current] when network succeeds; never throws.
  ///
  /// Skips Firestore when [force] is false and the last successful refresh is
  /// within [catalogRefreshTtl]. Concurrent calls share one in-flight request.
  static Future<CatalogFirestoreRefreshResult> refreshFromFirestore({
    bool force = false,
  }) async {
    if (!force && _isWithinRefreshTtl(DateTime.now())) {
      return CatalogFirestoreRefreshResult.skippedWithinTtl;
    }

    final pending = _refreshInFlight;
    if (pending != null) return pending;

    final refresh = _refreshFromFirestoreImpl();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  static Future<CatalogFirestoreRefreshResult> _refreshFromFirestoreImpl() async {
    try {
      final fresh = await _loadFirestore().timeout(firestoreTimeout);
      await _commitFirestoreBundle(fresh, notifyListeners: true);
      _lastFirestoreRefreshAt = DateTime.now();
      return CatalogFirestoreRefreshResult.refreshed;
    } catch (e, st) {
      if (_memoryOrigin == CatalogBundleMemoryOrigin.bootstrapPlaceholder) {
        _memoryOrigin = CatalogBundleMemoryOrigin.resolved;
      }
      debugPrint('CatalogBundleCache: Firestore refresh skipped: $e\n$st');
      return CatalogFirestoreRefreshResult.failed;
    }
  }

  static Future<CatalogSeedBundle> _loadNetworkThenPersistedOrSeed() async {
    try {
      final remote = await _loadFirestore().timeout(firestoreTimeout);
      await _commitFirestoreBundle(remote, notifyListeners: true);
      return remote;
    } catch (_) {
      final persisted = await _loadPersisted();
      if (persisted != null) {
        _setMemoryBundle(persisted, CatalogBundleMemoryOrigin.persisted);
        return persisted;
      }
      if (!await _hasCompletedFirestoreSync()) {
        final seed = await _loadSeed();
        _setMemoryBundle(seed, CatalogBundleMemoryOrigin.seed);
        return seed;
      }
      final empty = _emptyBundle();
      _setMemoryBundle(empty, CatalogBundleMemoryOrigin.resolved);
      return empty;
    }
  }

  static Future<CatalogSeedBundle?> _loadLocalCatalog() async {
    return _loadPersisted();
  }

  static Future<CatalogSeedBundle?> _loadPersisted() {
    return loadPersistedOverride?.call() ?? CatalogBundlePersistence.load();
  }

  static Future<void> _persist(CatalogSeedBundle bundle) {
    return persistOverride?.call(bundle) ??
        CatalogBundlePersistence.save(bundle);
  }

  static Future<bool> _hasCompletedFirestoreSync() {
    return hasCompletedFirestoreSyncOverride?.call() ??
        CatalogBundlePersistence.hasCompletedFirestoreSync();
  }

  static Future<CatalogSeedBundle> _loadSeed() {
    return loadSeedOverride?.call() ?? loadCatalogSeedBundle();
  }

  static Future<CatalogSeedBundle> _loadFirestore() {
    return loadFirestoreOverride?.call() ?? loadFirestoreCatalogBundle();
  }

  /// Memory + listener update first; persistence is best-effort and must not
  /// block catalog consumers when the local write fails.
  static Future<void> _commitFirestoreBundle(
    CatalogSeedBundle fresh, {
    required bool notifyListeners,
  }) async {
    _setMemoryBundle(fresh, CatalogBundleMemoryOrigin.firestore);
    _logRefresh(fresh);
    if (notifyListeners) {
      _notifyBundleReplaced();
    }
    try {
      await _persist(fresh);
    } catch (e, st) {
      debugPrint('CatalogBundleCache: catalog persist skipped: $e\n$st');
    }
  }

  static CatalogSeedBundle _emptyBundle() => const CatalogSeedBundle(
        brands: [],
        ips: [],
        series: [],
        figures: [],
      );

  static void _logStartup(CatalogBundleLoadSource source, CatalogSeedBundle bundle) {
    lastStartupSource = source;
    if (!kDebugMode) return;
    debugPrint(
      'CatalogBundleCache: startup source=${source.name} '
      'origin=${_memoryOrigin.name} '
      'brands=${bundle.brands.length} ips=${bundle.ips.length} '
      'series=${bundle.series.length} figures=${bundle.figures.length}',
    );
  }

  static void _logRefresh(CatalogSeedBundle bundle) {
    if (!kDebugMode) return;
    debugPrint(
      'CatalogBundleCache: refresh source=firestore '
      'origin=${_memoryOrigin.name} '
      'brands=${bundle.brands.length} ips=${bundle.ips.length} '
      'series=${bundle.series.length} figures=${bundle.figures.length}',
    );
  }
}
