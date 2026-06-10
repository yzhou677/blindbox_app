import 'dart:async';

import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_persistence.dart';
import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_loader.dart';
import 'package:flutter/foundation.dart';

/// In-memory catalog snapshot — static metadata only (no Storage URLs).
///
/// **Offline-first startup:** persisted Firestore snapshot (when available) →
/// bundled seed (first install / never synced) → background Firestore refresh.
/// After the first successful refresh, persisted data is authoritative on cold
/// start; deleted Firestore entries do not reappear from seed.
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

abstract final class CatalogBundleCache {
  static const Duration firestoreTimeout = Duration(seconds: 12);

  static CatalogSeedBundle? _bundle;
  static Future<CatalogSeedBundle>? _inFlight;

  static CatalogSeedBundle? get current => _bundle;

  static bool get hasValue => _bundle != null;

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
    _inFlight = null;
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
      _logStartup(CatalogBundleLoadSource.persisted, local);
      unawaited(refreshFromFirestore());
      return local;
    }

    if (!await _hasCompletedFirestoreSync()) {
      final seed = await _loadSeed();
      _bundle = seed;
      _logStartup(CatalogBundleLoadSource.seed, seed);
      unawaited(refreshFromFirestore());
      return seed;
    }

    final empty = _emptyBundle();
    _bundle = empty;
    _logStartup(CatalogBundleLoadSource.empty, empty);
    unawaited(refreshFromFirestore());
    return empty;
  }

  /// Returns cached bundle or loads once (deduped). Prefer [loadOfflineFirst] at startup.
  static Future<CatalogSeedBundle> getOrLoad() async {
    final cached = _bundle;
    if (cached != null) return cached;

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
  static Future<void> refreshFromFirestore() async {
    try {
      final fresh = await _loadFirestore().timeout(firestoreTimeout);
      await _commitFirestoreBundle(fresh, notifyListeners: true);
    } catch (e, st) {
      debugPrint('CatalogBundleCache: Firestore refresh skipped: $e\n$st');
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
        return persisted;
      }
      if (!await _hasCompletedFirestoreSync()) {
        final seed = await _loadSeed();
        _bundle = seed;
        return seed;
      }
      final empty = _emptyBundle();
      _bundle = empty;
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
