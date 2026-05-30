/// Production defaults for catalog image disk cache lifecycle.
///
/// Disk cache is a **resilience layer** — not canonical storage. Network/Storage
/// remains the freshness source; local bytes degrade gracefully offline.
abstract final class CatalogImageCachePolicy {
  CatalogImageCachePolicy._();

  /// LRU eviction target — oldest-accessed entries removed when exceeded.
  static const int maxCacheBytes = 150 * 1024 * 1024;

  /// After this age, a disk entry is **stale** (still rendered immediately).
  static const Duration maxEntryAge = Duration(days: 14);

  /// Minimum interval between background refresh attempts for the same key.
  static const Duration refreshCooldown = Duration(hours: 24);
}

/// Result of a disk cache lookup — path plus freshness hints for the resolver.
final class CatalogDiskCacheHit {
  const CatalogDiskCacheHit({
    required this.localPath,
    required this.isStale,
    required this.writtenAt,
  });

  final String localPath;
  final bool isStale;
  final DateTime writtenAt;
}
