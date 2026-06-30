import 'dart:io';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_codec.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable on-device cache for the last successful Firestore catalog snapshot.
abstract final class CatalogBundlePersistence {
  CatalogBundlePersistence._();

  static const _syncedPrefsKey = 'catalog_bundle_firestore_synced_v1';
  static const _bundleFileName = 'catalog_bundle_v1.json';
  static const _bundleTempFileName = 'catalog_bundle_v1.json.tmp';

  @visibleForTesting
  static Directory? testRootOverride;

  static Future<void>? _saveInFlight;

  @visibleForTesting
  static void resetForTest() {
    testRootOverride = null;
    _saveInFlight = null;
  }

  static Future<bool> hasCompletedFirestoreSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncedPrefsKey) ?? false;
  }

  @visibleForTesting
  static Future<void> setFirestoreSyncCompletedForTest(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_syncedPrefsKey, true);
    } else {
      await prefs.remove(_syncedPrefsKey);
    }
  }

  static Future<CatalogSeedBundle?> load() async {
    if (kIsWeb) return null;
    try {
      final file = await _bundleFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return CatalogBundleCodec.tryDecode(raw);
    } on Object {
      return null;
    }
  }

  /// Atomically replaces the on-disk bundle and marks Firestore as synced.
  static Future<void> save(CatalogSeedBundle bundle) async {
    if (kIsWeb) return;
    final prior = _saveInFlight;
    if (prior != null) await prior;

    final op = _saveImpl(bundle);
    _saveInFlight = op;
    try {
      await op;
    } finally {
      if (identical(_saveInFlight, op)) _saveInFlight = null;
    }
  }

  static Future<void> _saveImpl(CatalogSeedBundle bundle) async {
    final root = await _cacheRoot();
    final target = File('${root.path}/$_bundleFileName');
    final temp = File('${root.path}/$_bundleTempFileName');
    final payload = CatalogBundleCodec.encode(bundle);
    await temp.writeAsString(payload, flush: true);
    // Copy-then-delete avoids Windows rename races when refreshes overlap.
    await target.writeAsString(await temp.readAsString(), flush: true);
    if (await temp.exists()) {
      await temp.delete();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncedPrefsKey, true);
  }

  @visibleForTesting
  static Future<void> writeCorruptBundleForTest(String raw) async {
    final root = await _cacheRoot();
    final target = File('${root.path}/$_bundleFileName');
    await target.writeAsString(raw, flush: true);
  }

  static Future<Directory> _cacheRoot() async {
    if (testRootOverride != null) {
      final root = testRootOverride!;
      if (!await root.exists()) {
        await root.create(recursive: true);
      }
      return root;
    }
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/catalog_bundle_cache');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  static Future<File> _bundleFile() async {
    final root = await _cacheRoot();
    return File('${root.path}/$_bundleFileName');
  }
}
