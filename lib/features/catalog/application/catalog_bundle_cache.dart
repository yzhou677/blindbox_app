import 'dart:async';

import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_loader.dart';
import 'package:flutter/foundation.dart';

/// In-memory catalog snapshot — static metadata only (no Storage URLs).
///
/// **Offline-first:** bundled seed is authoritative for first paint; Firestore refresh
/// is optional and must not block UI. See [loadOfflineFirst] and [getOrLoad].
abstract final class CatalogBundleCache {
  static const Duration firestoreTimeout = Duration(seconds: 12);

  static CatalogSeedBundle? _bundle;
  static Future<CatalogSeedBundle>? _inFlight;

  static CatalogSeedBundle? get current => _bundle;

  static bool get hasValue => _bundle != null;

  static void prime(CatalogSeedBundle bundle) {
    _bundle = bundle;
  }

  /// Bundled seed immediately, then optional background Firestore refresh.
  static Future<CatalogSeedBundle> loadOfflineFirst() async {
    if (_bundle != null) {
      unawaited(refreshFromFirestore());
      return _bundle!;
    }
    final seed = await loadCatalogSeedBundle();
    _bundle = seed;
    unawaited(refreshFromFirestore());
    return seed;
  }

  /// Returns cached bundle or loads once (deduped). Prefer [loadOfflineFirst] at startup.
  static Future<CatalogSeedBundle> getOrLoad() async {
    final cached = _bundle;
    if (cached != null) return cached;

    final pending = _inFlight;
    if (pending != null) return pending;

    final load = _loadNetworkThenSeed();
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
      final fresh = await loadFirestoreCatalogBundle().timeout(firestoreTimeout);
      _bundle = fresh;
    } catch (e, st) {
      debugPrint('CatalogBundleCache: Firestore refresh skipped: $e\n$st');
    }
  }

  static Future<CatalogSeedBundle> _loadNetworkThenSeed() async {
    try {
      final remote = await loadFirestoreCatalogBundle().timeout(firestoreTimeout);
      _bundle = remote;
      return remote;
    } catch (_) {
      final seed = await loadCatalogSeedBundle();
      _bundle = seed;
      return seed;
    }
  }
}
