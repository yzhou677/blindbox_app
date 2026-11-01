import 'dart:async';

import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_merge.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_persistence.dart';
import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum CatalogBundleLoadSource {
  /// In-memory bundle reused within the same process (e.g. second call).
  memory,

  /// Last successful Firestore snapshot from on-device persistence.
  persisted,

  /// No persisted snapshot — bootstrap placeholder until refresh/load completes.
  empty,
}

enum CatalogFirestoreRefreshResult {
  /// Bundle replaced via full or incremental sync.
  refreshed,

  /// Meta watermark unchanged and within full-reconcile window — no collection queries.
  unchanged,

  /// Legacy alias used by older call sites / tests for “did not fetch full catalog”.
  skippedWithinTtl,

  failed,
}

/// In-memory provenance for [_bundle] inside [CatalogBundleCache].
enum CatalogBundleMemoryOrigin {
  none,
  bootstrapPlaceholder,
  persisted,
  firestore,
  resolved;

  bool get isCatalogReady =>
      this != none && this != CatalogBundleMemoryOrigin.bootstrapPlaceholder;
}

/// In-memory catalog snapshot — static metadata only (no Storage URLs).
///
/// **Sync policy (PR2b)**
///
/// 1. Read `meta/catalog.lastUpdatedAt`.
/// 2. If `lastSyncAt` is set and meta ≤ lastSyncAt and last full sync &lt; 24h →
///    keep cache (zero collection reads).
/// 3. Else if local bundle + lastSyncAt exist → incremental
///    `updatedAt > lastSyncAt` merge (on failure → full `.get()`).
/// 4. Else → full `.get()` (first install / no watermark).
/// 5. Full `.get()` also when last full sync ≥ 24h (兜底校对) or `force: true`.
abstract final class CatalogBundleCache {
  static const Duration firestoreTimeout = Duration(seconds: 12);

  /// Full-collection reconcile interval (not the meta check interval).
  static const Duration catalogRefreshTtl = Duration(hours: 24);

  static CatalogSeedBundle? _bundle;
  static CatalogBundleMemoryOrigin _memoryOrigin =
      CatalogBundleMemoryOrigin.none;

  static Future<CatalogSeedBundle>? _inFlight;
  static Future<CatalogFirestoreRefreshResult>? _refreshInFlight;
  static DateTime? _lastFirestoreRefreshAt;
  static DateTime? _lastSyncAtMemory;

  static StreamSubscription<dynamic>? _metaSubscription;

  static CatalogSeedBundle? get current => _bundle;

  static CatalogBundleMemoryOrigin get memoryOrigin => _memoryOrigin;

  static bool get hasValue => _bundle != null;

  static bool get isCatalogReady =>
      _memoryOrigin.isCatalogReady && _bundle != null;

  static bool get isRefreshInFlight => _refreshInFlight != null;

  @visibleForTesting
  static CatalogBundleMemoryOrigin get memoryOriginForTest => _memoryOrigin;

  @visibleForTesting
  static DateTime? get lastFirestoreRefreshAt => _lastFirestoreRefreshAt;

  @visibleForTesting
  static DateTime? get lastSyncAtMemoryForTest => _lastSyncAtMemory;

  @visibleForTesting
  static void setLastFirestoreRefreshAtForTest(DateTime? at) {
    _lastFirestoreRefreshAt = at;
  }

  @visibleForTesting
  static void setLastSyncAtMemoryForTest(DateTime? at) {
    _lastSyncAtMemory = at;
  }

  static CatalogBundleLoadSource? lastStartupSource;

  @visibleForTesting
  static Future<CatalogSeedBundle> Function()? loadFirestoreOverride;

  @visibleForTesting
  static Future<CatalogSeedBundle> Function(DateTime since)? loadDeltaOverride;

  @visibleForTesting
  static Future<DateTime?> Function()? loadMetaOverride;

  @visibleForTesting
  static Future<CatalogSeedBundle?> Function()? loadPersistedOverride;

  @visibleForTesting
  static Future<void> Function(CatalogSeedBundle bundle)? persistOverride;

  @visibleForTesting
  static Future<DateTime?> Function()? loadLastSyncAtOverride;

  @visibleForTesting
  static Future<void> Function(DateTime at)? saveLastSyncAtOverride;

  @visibleForTesting
  static Future<DateTime?> Function()? loadLastFullSyncAtOverride;

  @visibleForTesting
  static Future<void> Function(DateTime at)? saveLastFullSyncAtOverride;

  /// When non-null, [startMetaListener] uses this instead of Firestore snapshots.
  @visibleForTesting
  static Stream<DateTime?> Function()? metaSnapshotStreamOverride;

  static void prime(CatalogSeedBundle bundle) {
    _setMemoryBundle(bundle, CatalogBundleMemoryOrigin.firestore);
  }

  @visibleForTesting
  static void primeBootstrapPlaceholderForTest() {
    _setMemoryBundle(
      _emptyBundle(),
      CatalogBundleMemoryOrigin.bootstrapPlaceholder,
    );
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

  static void Function()? onBundleReplaced;

  static final List<void Function()> _bundleReplacedListeners = [];
  static final List<void Function()> _refreshStateListeners = [];

  static void Function() addRefreshStateListener(void Function() listener) {
    _refreshStateListeners.add(listener);
    return () {
      _refreshStateListeners.remove(listener);
    };
  }

  @visibleForTesting
  static int get refreshStateListenerCountForTest =>
      _refreshStateListeners.length;

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

  static void _notifyRefreshStateChanged() {
    for (final listener in List<void Function()>.of(_refreshStateListeners)) {
      listener();
    }
  }

  @visibleForTesting
  static void triggerBundleReplacedForTest() => _notifyBundleReplaced();

  @visibleForTesting
  static void resetForTest() {
    unawaited(stopMetaListener());
    _clearMemoryBundle();
    _inFlight = null;
    _refreshInFlight = null;
    _lastFirestoreRefreshAt = null;
    _lastSyncAtMemory = null;
    onBundleReplaced = null;
    _bundleReplacedListeners.clear();
    _refreshStateListeners.clear();
    loadFirestoreOverride = null;
    loadDeltaOverride = null;
    loadMetaOverride = null;
    loadPersistedOverride = null;
    persistOverride = null;
    loadLastSyncAtOverride = null;
    saveLastSyncAtOverride = null;
    loadLastFullSyncAtOverride = null;
    saveLastFullSyncAtOverride = null;
    metaSnapshotStreamOverride = null;
    ensureFirebaseForMetaListenerOverride = null;
    lastStartupSource = null;
  }

  static Future<CatalogSeedBundle> loadOfflineFirst() async {
    if (_bundle != null) {
      _logStartup(CatalogBundleLoadSource.memory, _bundle!);
      unawaited(refreshFromFirestore());
      return _bundle!;
    }

    final local = await _loadLocalCatalog();
    if (local != null) {
      _setMemoryBundle(local, CatalogBundleMemoryOrigin.persisted);
      _lastSyncAtMemory = await _readLastSyncAt();
      _lastFirestoreRefreshAt = await _readLastFullSyncAt();
      _logStartup(CatalogBundleLoadSource.persisted, local);
      unawaited(refreshFromFirestore());
      return local;
    }

    final empty = _emptyBundle();
    _setMemoryBundle(empty, CatalogBundleMemoryOrigin.bootstrapPlaceholder);
    _logStartup(CatalogBundleLoadSource.empty, empty);
    unawaited(refreshFromFirestore());
    return empty;
  }

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
    }

    final pending = _inFlight;
    if (pending != null) return pending;

    final load = _loadNetworkThenPersisted();
    _inFlight = load;
    try {
      return await load;
    } finally {
      if (identical(_inFlight, load)) _inFlight = null;
    }
  }

  /// Stale-while-revalidate against meta + optional delta / full get.
  static Future<CatalogFirestoreRefreshResult> refreshFromFirestore({
    bool force = false,
  }) async {
    final pending = _refreshInFlight;
    if (pending != null) return pending;

    final refresh = _refreshFromFirestoreImpl(force: force);
    _refreshInFlight = refresh;
    _notifyRefreshStateChanged();
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
      _notifyRefreshStateChanged();
    }
  }

  static Future<CatalogFirestoreRefreshResult> _refreshFromFirestoreImpl({
    required bool force,
  }) async {
    try {
      if (force || !isCatalogReady) {
        return await _fullRefresh();
      }

      final now = DateTime.now().toUtc();
      final lastSync = _lastSyncAtMemory ?? await _readLastSyncAt();
      final lastFull = _lastFirestoreRefreshAt ?? await _readLastFullSyncAt();
      final needFullByAge =
          lastFull == null ||
          now.difference(lastFull) >= catalogRefreshTtl;

      final metaAt = await _loadMeta().timeout(firestoreTimeout);

      if (!needFullByAge &&
          lastSync != null &&
          metaAt != null &&
          !metaAt.isAfter(lastSync)) {
        _lastSyncAtMemory = lastSync;
        return CatalogFirestoreRefreshResult.unchanged;
      }

      if (needFullByAge || lastSync == null || metaAt == null) {
        return await _fullRefresh(metaHint: metaAt);
      }

      try {
        final delta = await _loadDelta(lastSync).timeout(firestoreTimeout);
        final merged = mergeCatalogSeedBundle(_bundle!, delta);
        await _commitFirestoreBundle(merged, notifyListeners: true);
        await _writeLastSyncAt(metaAt);
        _lastSyncAtMemory = metaAt;
        return CatalogFirestoreRefreshResult.refreshed;
      } catch (e, st) {
        debugPrint(
          'CatalogBundleCache: incremental sync failed, falling back to full: $e\n$st',
        );
        return await _fullRefresh(metaHint: metaAt);
      }
    } catch (e, st) {
      if (_memoryOrigin == CatalogBundleMemoryOrigin.bootstrapPlaceholder) {
        _memoryOrigin = CatalogBundleMemoryOrigin.resolved;
        _notifyBundleReplaced();
      }
      debugPrint('CatalogBundleCache: Firestore refresh skipped: $e\n$st');
      return CatalogFirestoreRefreshResult.failed;
    }
  }

  static Future<CatalogFirestoreRefreshResult> _fullRefresh({
    DateTime? metaHint,
  }) async {
    final fresh = await _loadFirestore().timeout(firestoreTimeout);
    await _commitFirestoreBundle(fresh, notifyListeners: true);
    final now = DateTime.now().toUtc();
    _lastFirestoreRefreshAt = now;
    await _writeLastFullSyncAt(now);
    DateTime? metaAt = metaHint;
    if (metaAt == null) {
      try {
        metaAt = await _loadMeta().timeout(firestoreTimeout);
      } catch (e, st) {
        debugPrint('CatalogBundleCache: meta watermark read skipped: $e\n$st');
      }
    }
    final syncAt = metaAt ?? now;
    await _writeLastSyncAt(syncAt);
    _lastSyncAtMemory = syncAt;
    return CatalogFirestoreRefreshResult.refreshed;
  }

  static Future<CatalogSeedBundle> _loadNetworkThenPersisted() async {
    try {
      final outcome = await refreshFromFirestore(force: true);
      if (outcome == CatalogFirestoreRefreshResult.refreshed &&
          _bundle != null) {
        return _bundle!;
      }
      if (_bundle != null && isCatalogReady) return _bundle!;
      throw StateError('catalog refresh failed');
    } catch (_) {
      final persisted = await _loadPersisted();
      if (persisted != null) {
        _setMemoryBundle(persisted, CatalogBundleMemoryOrigin.persisted);
        return persisted;
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

  static Future<CatalogSeedBundle> _loadFirestore() {
    return loadFirestoreOverride?.call() ?? loadFirestoreCatalogBundle();
  }

  static Future<CatalogSeedBundle> _loadDelta(DateTime since) {
    return loadDeltaOverride?.call(since) ??
        loadFirestoreCatalogDelta(since: since);
  }

  static Future<DateTime?> _loadMeta() {
    return loadMetaOverride?.call() ?? loadCatalogMetaLastUpdatedAt();
  }

  static Future<DateTime?> _readLastSyncAt() {
    return loadLastSyncAtOverride?.call() ??
        CatalogBundlePersistence.loadLastSyncAt();
  }

  static Future<void> _writeLastSyncAt(DateTime at) {
    return saveLastSyncAtOverride?.call(at) ??
        CatalogBundlePersistence.saveLastSyncAt(at);
  }

  static Future<DateTime?> _readLastFullSyncAt() {
    return loadLastFullSyncAtOverride?.call() ??
        CatalogBundlePersistence.loadLastFullSyncAt();
  }

  static Future<void> _writeLastFullSyncAt(DateTime at) {
    return saveLastFullSyncAtOverride?.call(at) ??
        CatalogBundlePersistence.saveLastFullSyncAt(at);
  }

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

  /// Foreground-only listener on `meta/catalog`. Cancel with [stopMetaListener].
  static Future<void> startMetaListener() async {
    await stopMetaListener();
    final override = metaSnapshotStreamOverride;
    if (override != null) {
      _metaSubscription = override().listen(_onMetaWatermark);
      return;
    }

    try {
      await ensureFirebaseForMetaListener();
      _metaSubscription = FirebaseFirestore.instance
          .collection('meta')
          .doc('catalog')
          .snapshots()
          .listen(
            (snap) {
              final raw = snap.data()?['lastUpdatedAt'];
              if (raw is! Timestamp) return;
              _onMetaWatermark(raw.toDate().toUtc());
            },
            onError: (Object e, StackTrace st) {
              debugPrint('CatalogBundleCache: meta listener error: $e\n$st');
            },
          );
    } catch (e, st) {
      debugPrint('CatalogBundleCache: meta listener start skipped: $e\n$st');
    }
  }

  static void _onMetaWatermark(DateTime? at) {
    if (at == null) return;
    final last = _lastSyncAtMemory;
    if (last != null && !at.isAfter(last)) return;
    unawaited(refreshFromFirestore());
  }

  /// Test-seam Firebase init before attaching the meta snapshot listener.
  @visibleForTesting
  static Future<void> Function()? ensureFirebaseForMetaListenerOverride;

  static Future<void> ensureFirebaseForMetaListener() async {
    final override = ensureFirebaseForMetaListenerOverride;
    if (override != null) {
      await override();
      return;
    }
    await ensureFirebaseInitialized();
  }

  static Future<void> stopMetaListener() async {
    await _metaSubscription?.cancel();
    _metaSubscription = null;
  }

  static CatalogSeedBundle _emptyBundle() =>
      const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []);

  static void _logStartup(
    CatalogBundleLoadSource source,
    CatalogSeedBundle bundle,
  ) {
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
