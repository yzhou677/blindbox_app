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
/// [_bundle] may hold a **bootstrap placeholder** (intentionally empty after
/// sync with no persisted snapshot). Placeholders paint offline-first startup
/// but are **not** catalog-ready: [getOrLoad] awaits the startup Firestore
/// refresh (or falls through to the shared network load) instead of returning
/// the empty slot immediately.
///
/// **State machine (what callers receive)**
///
/// | State | [loadOfflineFirst] | [getOrLoad] |
/// |-------|-------------------|-------------|
/// | Persisted bundle | Returns disk snapshot; starts background refresh | Returns same bundle immediately |
/// | Seed bundle | Returns seed; starts background refresh | Returns seed immediately |
/// | Bootstrap placeholder | Returns empty; starts background refresh | Awaits refresh / shared load — not empty until refresh resolves or load exhausts fallbacks |
/// | Ready bundle (post-refresh or [prime]) | Returns memory bundle | Returns memory bundle immediately |
/// | Resolved empty (refresh/load failed) | Returns empty | Returns empty (no re-fetch while placeholder was resolved) |
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

  /// True when [_bundle] is an intentional empty bootstrap from
  /// [loadOfflineFirst] (synced before, no persisted snapshot). Not
  /// catalog-ready until startup refresh or [getOrLoad] load completes.
  static bool _bootstrapPlaceholder = false;

  static Future<CatalogSeedBundle>? _inFlight;
  static Future<CatalogFirestoreRefreshResult>? _refreshInFlight;
  static DateTime? _lastFirestoreRefreshAt;

  static CatalogSeedBundle? get current => _bundle;

  /// Whether [_bundle] is non-null (includes bootstrap placeholders).
  static bool get hasValue => _bundle != null;

  /// Whether [_bundle] is safe to treat as a completed catalog load.
  static bool get isCatalogReady => _bundle != null && !_bootstrapPlaceholder;

  @visibleForTesting
  static bool get isBootstrapPlaceholderForTest => _bootstrapPlaceholder;

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
    _bundle = bundle;
    _markBundleReady();
  }

  static void _markBundleReady() {
    _bootstrapPlaceholder = false;
  }

  static void _setBootstrapPlaceholder(CatalogSeedBundle empty) {
    _bundle = empty;
    _bootstrapPlaceholder = true;
  }

  /// Optional hook after a successful Firestore refresh replaces [_bundle].
  ///
  /// Registered by [CatalogBundleRefreshBridge] to invalidate Discover feed.
  static void Function()? onBundleReplaced;

  static void _notifyBundleReplaced() => onBundleReplaced?.call();

  @visibleForTesting
  static void triggerBundleReplacedForTest() => _notifyBundleReplaced();

  @visibleForTesting
  static void resetForTest() {
    _bundle = null;
    _bootstrapPlaceholder = false;
    _inFlight = null;
    _refreshInFlight = null;
    _lastFirestoreRefreshAt = null;
    onBundleReplaced = null;
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
      _bundle = local;
      _markBundleReady();
      _logStartup(CatalogBundleLoadSource.persisted, local);
      unawaited(refreshFromFirestore());
      return local;
    }

    if (!await _hasCompletedFirestoreSync()) {
      final seed = await _loadSeed();
      _bundle = seed;
      _markBundleReady();
      _logStartup(CatalogBundleLoadSource.seed, seed);
      unawaited(refreshFromFirestore());
      return seed;
    }

    final empty = _emptyBundle();
    _setBootstrapPlaceholder(empty);
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

    if (_bootstrapPlaceholder) {
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
      if (_bootstrapPlaceholder) {
        _markBundleReady();
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
        _bundle = persisted;
        _markBundleReady();
        return persisted;
      }
      if (!await _hasCompletedFirestoreSync()) {
        final seed = await _loadSeed();
        _bundle = seed;
        _markBundleReady();
        return seed;
      }
      final empty = _emptyBundle();
      _bundle = empty;
      _markBundleReady();
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
    _bundle = fresh;
    _markBundleReady();
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
      'brands=${bundle.brands.length} ips=${bundle.ips.length} '
      'series=${bundle.series.length} figures=${bundle.figures.length}',
    );
  }

  static void _logRefresh(CatalogSeedBundle bundle) {
    if (!kDebugMode) return;
    debugPrint(
      'CatalogBundleCache: refresh source=firestore '
      'brands=${bundle.brands.length} ips=${bundle.ips.length} '
      'series=${bundle.series.length} figures=${bundle.figures.length}',
    );
  }
}
