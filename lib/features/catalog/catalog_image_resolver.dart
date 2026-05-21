import 'package:flutter/services.dart';

/// Transforms portable catalog [imageKey] values into bundled asset paths.
///
/// Catalog documents store only opaque keys (no paths, no URLs). This resolver
/// maps a key to a file under `assets/catalog/…` when the app bundle includes it.
///
/// **Mixed formats:** The ingestion pipeline keeps each image's original extension
/// (`.avif`, `.webp`, `.png`, `.jpg`). We probe the asset bundle in priority order
/// and use the first file that exists — not a single hard-coded `.png` path.
abstract final class CatalogImageResolver {
  static const String figuresRoot = 'assets/catalog/figures';
  static const String seriesRoot = 'assets/catalog/series';

  /// Checked in order when resolving a bundled file for an [imageKey].
  /// Prefer modern/smaller formats first; `.jpg` last for legacy art.
  static const List<String> assetExtensions = [
    '.avif',
    '.webp',
    '.png',
    '.jpg',
  ];

  static Set<String>? _bundleAssetKeys;

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
      RegExp(r'\.(avif|webp|png|jpe?g)$', caseSensitive: false),
      '',
    );
    return stem.trim();
  }
}
