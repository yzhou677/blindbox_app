import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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
  /// When true (default), after a bundled miss, resolve from Firebase Storage.
  ///
  /// Discover / catalog UI is designed around Firestore metadata + Storage art.
  /// Bundled `assets/catalog/**` is offline-first cache for a small seed subset.
  ///
  /// Set `CATALOG_STORAGE_FALLBACK=false` only to suppress Storage probes (e.g.
  /// catalog-only dev with placeholders). Missing keys are negative-cached so
  /// repeat 404 log spam is avoided without disabling Storage for valid keys.
  static bool get storageFallbackEnabled {
    if (storageFallbackOverride != null) return storageFallbackOverride!;
    return const bool.fromEnvironment(
      'CATALOG_STORAGE_FALLBACK',
      defaultValue: true,
    );
  }

  @visibleForTesting
  static bool? storageFallbackOverride;

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
  static Future<void>? _ensureReadyFuture;
  static final Map<String, String> _storageUrlCache = {};
  static final Set<String> _storageMissingCache = <String>{};
  static final Map<String, Future<String?>> _storageResolveInFlight = {};
  static final Set<String> _debugLoggedMissingKeys = <String>{};

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
    _ensureReadyFuture ??= _loadAssetManifest();
    await _ensureReadyFuture;
  }

  static Future<void> _loadAssetManifest() async {
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
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    await ensureReady();
    final hit = _firstExisting(figuresRoot, k);
    _traceResolution(
      imageKey: k,
      kind: CatalogImageKind.figure,
      phase: 'bundled',
      attemptedPath: _lastProbedBundledPath,
      hit: hit != null,
      storageSkipped: null,
      outcome: hit != null ? 'bundled_asset' : 'bundled_miss',
    );
    return hit;
  }

  /// First existing series asset for [imageKey], or null if none are bundled.
  static Future<String?> resolveSeriesAsset(String imageKey) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    await ensureReady();
    final hit = _firstExisting(seriesRoot, k);
    _traceResolution(
      imageKey: k,
      kind: CatalogImageKind.series,
      phase: 'bundled',
      attemptedPath: _lastProbedBundledPath,
      hit: hit != null,
      storageSkipped: null,
      outcome: hit != null ? 'bundled_asset' : 'bundled_miss',
    );
    return hit;
  }

  /// Firebase Storage URL only — does not probe bundled assets.
  static Future<String?> resolveFigureStorageRef(String imageKey) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    return _resolveStorageDisplayRef(CatalogImageKind.figure, k);
  }

  /// Firebase Storage URL only — does not probe bundled assets.
  static Future<String?> resolveSeriesStorageRef(String imageKey) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    return _resolveStorageDisplayRef(CatalogImageKind.series, k);
  }

  /// Bundled asset path, else Storage when [storageFallbackEnabled].
  static Future<String?> resolveFigureDisplayRef(String imageKey) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    final asset = await resolveFigureAsset(k);
    if (asset != null) return asset;
    final storage = await _resolveStorageDisplayRef(CatalogImageKind.figure, k);
    _traceResolution(
      imageKey: k,
      kind: CatalogImageKind.figure,
      phase: 'display_ref',
      outcome: storage != null ? 'storage_url' : 'null',
    );
    return storage;
  }

  /// Bundled asset path, else Storage when [storageFallbackEnabled].
  static Future<String?> resolveSeriesDisplayRef(String imageKey) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    final asset = await resolveSeriesAsset(k);
    if (asset != null) return asset;
    final storage = await _resolveStorageDisplayRef(CatalogImageKind.series, k);
    _traceResolution(
      imageKey: k,
      kind: CatalogImageKind.series,
      phase: 'display_ref',
      outcome: storage != null ? 'storage_url' : 'null',
    );
    return storage;
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

  static String? _lastProbedBundledPath;

  static String? _firstExisting(String root, String imageKey) {
    final keys = _bundleAssetKeys;
    if (keys == null) {
      _lastProbedBundledPath = null;
      return null;
    }
    for (final path in candidatePaths(root, imageKey)) {
      _lastProbedBundledPath = path;
      if (keys.contains(path)) return path;
    }
    _lastProbedBundledPath = null;
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
    if (_storageMissingCache.contains(primaryCacheKey)) return null;
    final inFlight = _storageResolveInFlight[primaryCacheKey];
    if (inFlight != null) return inFlight;

    if (!storageFallbackEnabled) {
      _traceResolution(
        imageKey: k,
        kind: kind,
        phase: 'storage',
        storageSkipped: true,
        outcome: 'skipped_disabled',
      );
      return null;
    }
    if (!_firebaseStorageReady) {
      _traceResolution(
        imageKey: k,
        kind: kind,
        phase: 'storage',
        storageSkipped: true,
        outcome: 'skipped_firebase_unready',
      );
      return null;
    }

    final future = _resolveStorageDisplayRefUncached(
      kind: kind,
      imageKey: k,
      primaryCacheKey: primaryCacheKey,
    );
    _storageResolveInFlight[primaryCacheKey] = future;
    try {
      return await future;
    } finally {
      _storageResolveInFlight.remove(primaryCacheKey);
    }
  }

  static Future<String?> _resolveStorageDisplayRefUncached({
    required CatalogImageKind kind,
    required String imageKey,
    required String primaryCacheKey,
  }) async {
    var sawOnlyObjectNotFound = true;
    final root = FirebaseStorage.instance.ref();
    for (final ext in assetExtensions) {
      final path = storageObjectPath(
        kind: kind,
        imageKey: imageKey,
        extension: ext,
      );
      try {
        final url = await root
            .child(path)
            .getDownloadURL()
            .timeout(storageUrlTimeout);
        _storageUrlCache[primaryCacheKey] = url;
        _storageMissingCache.remove(primaryCacheKey);
        _traceResolution(
          imageKey: imageKey,
          kind: kind,
          phase: 'storage',
          attemptedPath: path,
          hit: true,
          storageSkipped: false,
          outcome: 'storage_url',
        );
        return url;
      } on TimeoutException {
        sawOnlyObjectNotFound = false;
        continue;
      } on FirebaseException catch (e) {
        if (_isObjectNotFound(e)) continue;
        if (e.code == 'no-app') return null;
        sawOnlyObjectNotFound = false;
        return null;
      } on Object {
        sawOnlyObjectNotFound = false;
        return null;
      }
    }
    if (sawOnlyObjectNotFound) {
      // Missing object for all known extensions: cache as absent so repeated
      // UI rebuilds do not keep probing Storage and spamming 404 logs.
      _storageMissingCache.add(primaryCacheKey);
      _debugLogMissingKeyOnce(kind: kind, imageKey: imageKey);
    }
    _traceResolution(
      imageKey: imageKey,
      kind: kind,
      phase: 'storage',
      storageSkipped: false,
      outcome: 'storage_miss',
    );
    return null;
  }

  static void _traceResolution({
    required String imageKey,
    required CatalogImageKind kind,
    required String phase,
    String? attemptedPath,
    bool? hit,
    bool? storageSkipped,
    String? outcome,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'CatalogImageResolver[$phase] imageKey="$imageKey" kind=${kind.name} '
      'path=${attemptedPath ?? '-'} hit=${hit ?? '-'} '
      'storageSkipped=${storageSkipped ?? '-'} outcome=${outcome ?? '-'}',
    );
  }

  static bool _isObjectNotFound(FirebaseException e) {
    final code = e.code.toLowerCase();
    if (code == 'object-not-found' || code == 'not-found' || code == '404') {
      return true;
    }
    final msg = (e.message ?? '').toLowerCase();
    // Android StorageException sometimes surfaces only as "-13010 / 404".
    return msg.contains('not found') ||
        msg.contains('"code": 404') ||
        msg.contains('"code":404') ||
        msg.contains('-13010');
  }

  static void _debugLogMissingKeyOnce({
    required CatalogImageKind kind,
    required String imageKey,
  }) {
    if (!kDebugMode) return;
    final marker = '${kind.name}:$imageKey';
    if (_debugLoggedMissingKeys.contains(marker)) return;
    _debugLoggedMissingKeys.add(marker);
    debugPrint(
      'CatalogImageResolver: missing Storage asset for '
      '${kind.name} imageKey="$imageKey" (all extensions probed).',
    );
  }

  /// Debug helper to inspect all missing Storage image keys seen this session.
  ///
  /// Output is grouped by kind (`series` / `figure`) and sorted for quick
  /// copy/paste into backfill scripts. No-op outside debug mode.
  static void debugDumpMissingKeys() {
    if (!kDebugMode) return;
    if (_debugLoggedMissingKeys.isEmpty) {
      debugPrint('CatalogImageResolver: no missing Storage image keys recorded.');
      return;
    }

    final grouped = <String, List<String>>{};
    for (final marker in _debugLoggedMissingKeys) {
      final sep = marker.indexOf(':');
      if (sep <= 0 || sep >= marker.length - 1) continue;
      final kind = marker.substring(0, sep);
      final key = marker.substring(sep + 1);
      grouped.putIfAbsent(kind, () => <String>[]).add(key);
    }
    for (final keys in grouped.values) {
      keys.sort();
    }

    debugPrint('CatalogImageResolver: missing Storage image keys snapshot:');
    for (final kind in <String>['series', 'figure']) {
      final keys = grouped[kind];
      if (keys == null || keys.isEmpty) continue;
      debugPrint('  $kind (${keys.length}): ${keys.join(', ')}');
    }
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
