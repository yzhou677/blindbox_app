/// Transforms portable catalog [imageKey] values into bundled asset paths.
///
/// Swap or extend later for Firebase Storage / CDN URLs without changing
/// Firestore documents (keys stay opaque identifiers).
abstract final class CatalogImageResolver {
  static const String figuresRoot = 'assets/catalog/figures';
  static const String seriesRoot = 'assets/catalog/series';

  /// Local bundled figure PNG (deterministic naming).
  static String figureAsset(String imageKey) {
    final k = imageKey.trim();
    return '$figuresRoot/$k.png';
  }

  /// Local bundled series PNG.
  static String seriesAsset(String imageKey) {
    final k = imageKey.trim();
    return '$seriesRoot/$k.png';
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
    final stem =
        last.replaceFirst(RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false), '');
    return stem.trim();
  }
}
