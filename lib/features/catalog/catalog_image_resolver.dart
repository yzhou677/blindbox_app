import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

/// Resolves catalog art from [imageKey] only — never from Firestore paths or URLs.
///
/// **Firestore:** canonical metadata (`imageKey`, ids, display names). No Storage URLs,
/// no `imagePath`, no binary fields on catalog documents.
///
/// **Firebase Storage:** binary assets at deterministic paths:
/// - `catalog/series/<imageKey>.<ext>`
/// - `catalog/figures/<imageKey>.<ext>`
///
/// **Runtime:** this resolver builds Storage paths from [imageKey] + [CatalogImageKind]
/// + [assetExtensions], probes bundled assets first, then Storage. Download URLs exist
/// only in memory for widgets — not written back to Firestore or shelf [imageKey].
abstract final class CatalogImageResolver {
  static const Duration storageUrlTimeout = Duration(seconds: 8);

  static const String figuresRoot = 'assets/catalog/figures';
  static const String seriesRoot = 'assets/catalog/series';

  /// Probe order for bundled assets and Storage (`catalog/series|figures/<imageKey><ext>`).
  ///
  /// Bucket mix is mostly png / webp / jpg with some avif — never assume a single format.
  /// Each [imageKey] tries every extension here until one object exists (or all miss → placeholder).
  static const List<String> assetExtensions = [
    '.avif',
    '.webp',
    '.png',
    '.jpg',
    '.jpeg',
  ];

  static Set<String>? _bundleAssetKeys;
  static final Map<String, String> _storageUrlCache = {};

  static const String storageFiguresPrefix = 'catalog/figures';
  static const String storageSeriesPrefix = 'catalog/series';

  /// Which Storage subtree to use under `catalog/`.
  static String storagePrefixFor(CatalogImageKind kind) => switch (kind) {
        CatalogImageKind.figure => storageFiguresPrefix,
        CatalogImageKind.series => storageSeriesPrefix,
      };

  /// Deterministic Storage object path: `catalog/{series|figures}/<imageKey><ext>`.
  static String storageObjectPath({
    required CatalogImageKind kind,
    required String imageKey,
    required String extension,
  }) {
    final k = imageKey.trim();
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return '${storagePrefixFor(kind)}/$k$ext';
  }

  /// Bundled asset path: `assets/catalog/{series|figures}/<imageKey><ext>`.
  static String bundledAssetPath({
    required CatalogImageKind kind,
    required String imageKey,
    required String extension,
  }) {
    final root = kind == CatalogImageKind.figure ? figuresRoot : seriesRoot;
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return '$root/${imageKey.trim()}$ext';
  }

  /// Loads [AssetManifest] once so sync lookups can find existing files.
  /// Called from catalog loaders; safe to call multiple times.
  static Future<void> ensureReady() async {
    if (_bundleAssetKeys != null) return;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _bundleAssetKeys = manifest.listAssets().toSet();
  }

  /// All candidate paths for [imageKey] under [root], highest-priority extension first.
  static Iterable<String> candidatePaths(String root, String imageKey) sync* {
    final k = imageKey.trim();
    if (k.isEmpty) return;
    for (final ext in assetExtensions) {
      yield '$root/$k$ext';
    }
  }

  /// First existing figure asset for [imageKey], or null if none are bundled.
  static Future<String?> resolveFigureAsset(String imageKey) async {
    await ensureReady();
    return _firstExisting(figuresRoot, imageKey);
  }

  /// First existing series asset for [imageKey], or null if none are bundled.
  static Future<String?> resolveSeriesAsset(String imageKey) async {
    await ensureReady();
    return _firstExisting(seriesRoot, imageKey);
  }

  /// Bundled asset path, else first existing Storage object — for UI display.
  static Future<String?> resolveFigureDisplayRef(String imageKey) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    final asset = await resolveFigureAsset(k);
    if (asset != null) return asset;
    return _resolveStorageDisplayRef(CatalogImageKind.figure, k);
  }

  /// Bundled asset path, else first existing Storage object — for UI display.
  static Future<String?> resolveSeriesDisplayRef(String imageKey) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    final asset = await resolveSeriesAsset(k);
    if (asset != null) return asset;
    return _resolveStorageDisplayRef(CatalogImageKind.series, k);
  }

  /// Bundled figure path for [imageKey].
  ///
  /// After [ensureReady], returns the first existing file (same order as
  /// [resolveFigureAsset]). Before warm-up, returns the highest-priority extension
  /// path as a best-effort guess (may 404 in [Image.asset] until [ensureReady] runs).
  static String figureAsset(String imageKey) {
    final existing = _firstExisting(figuresRoot, imageKey);
    if (existing != null) return existing;
    final k = imageKey.trim();
    return '$figuresRoot/$k${assetExtensions.first}';
  }

  /// Bundled series path for [imageKey] — same rules as [figureAsset].
  static String seriesAsset(String imageKey) {
    final existing = _firstExisting(seriesRoot, imageKey);
    if (existing != null) return existing;
    final k = imageKey.trim();
    return '$seriesRoot/$k${assetExtensions.first}';
  }

  static String? _firstExisting(String root, String imageKey) {
    final keys = _bundleAssetKeys;
    if (keys == null) return null;
    for (final path in candidatePaths(root, imageKey)) {
      if (keys.contains(path)) return path;
    }
    return null;
  }

  /// First existing Storage object for [kind] + [imageKey]; returns a download URL for UI only.
  static Future<String?> _resolveStorageDisplayRef(
    CatalogImageKind kind,
    String imageKey,
  ) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;

    final primaryCacheKey = '${storagePrefixFor(kind)}/$k';
    final cached = _storageUrlCache[primaryCacheKey];
    if (cached != null) return cached;

    if (!_firebaseStorageReady) return null;

    final root = FirebaseStorage.instance.ref();
    for (final ext in assetExtensions) {
      final path = storageObjectPath(kind: kind, imageKey: k, extension: ext);
      try {
        final url = await root
            .child(path)
            .getDownloadURL()
            .timeout(storageUrlTimeout);
        _storageUrlCache[primaryCacheKey] = url;
        return url;
      } on TimeoutException {
        continue;
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') continue;
        if (e.code == 'no-app') return null;
        return null;
      } on Object {
        return null;
      }
    }
    return null;
  }

  static bool get _firebaseStorageReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Derive an [imageKey] from legacy seed/Firestore `thumbnailAsset` paths.
  /// Returns empty when [legacyThumbnailAsset] is null/blank/non-filesystem path / URL.
  static String imageKeyFromLegacyThumbnailAsset(String? legacyThumbnailAsset) {
    final raw = legacyThumbnailAsset?.trim();
    if (raw == null || raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return '';
    final posix = raw.replaceAll(r'\', '/');
    final parts = posix.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final last = parts.last;
    final stem = last.replaceFirst(
      RegExp(r'\.(avif|webp|png|jpe?g|jpeg)$', caseSensitive: false),
      '',
    );
    return stem.trim();
  }
}

/// Catalog art subtree — maps to `catalog/series/` or `catalog/figures/` in Storage.
enum CatalogImageKind {
  series,
  figure,
}
