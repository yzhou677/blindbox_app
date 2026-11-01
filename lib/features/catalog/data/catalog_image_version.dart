import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';

/// Helpers for optional catalog `imageVersion` (Storage object `md5Hash`, base64).
///
/// Empty / missing version → legacy behavior (no key suffix, no URL bust).
abstract final class CatalogImageVersion {
  CatalogImageVersion._();

  /// Null when missing or blank.
  static String? normalize(String? imageVersion) {
    final v = imageVersion?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// Disk / session index key: `catalog/{series|figures}/<imageKey>` or
  /// `…/<imageKey>#<imageVersion>`.
  static String diskEntryKey({
    required CatalogImageKind kind,
    required String imageKey,
    String? imageVersion,
  }) {
    final base =
        '${CatalogImageResolver.storagePrefixFor(kind)}/${imageKey.trim()}';
    final v = normalize(imageVersion);
    if (v == null) return base;
    return '$base#$v';
  }

  /// Whether [entryKey] belongs to [imageKey] under [kind] (any version).
  static bool entryKeyMatchesImageKey({
    required String entryKey,
    required CatalogImageKind kind,
    required String imageKey,
  }) {
    final prefix =
        '${CatalogImageResolver.storagePrefixFor(kind)}/${imageKey.trim()}';
    return entryKey == prefix || entryKey.startsWith('$prefix#');
  }

  /// Appends `v=<encoded>` so CDN / download tokens see a new URL.
  ///
  /// Uses [Uri.encodeQueryComponent] so base64 `/`, `+`, `=` stay safe.
  /// Does nothing when [imageVersion] is empty. Never writes URLs to Firestore.
  static String appendQueryParam(String downloadUrl, String? imageVersion) {
    final v = normalize(imageVersion);
    if (v == null) return downloadUrl;
    final encoded = Uri.encodeQueryComponent(v);
    final sep = downloadUrl.contains('?') ? '&' : '?';
    return '$downloadUrl${sep}v=$encoded';
  }

  /// CachedNetworkImage / provider cache key — includes version when present.
  static String networkCacheKey(String urlOrRef, String? imageVersion) {
    final v = normalize(imageVersion);
    if (v == null) return urlOrRef;
    return '$urlOrRef#$v';
  }

  /// Filesystem-safe token for versioned cache filenames (reversible for base64).
  static String fileToken(String imageVersion) {
    return imageVersion
        .replaceAll('/', '-')
        .replaceAll('+', '.')
        .replaceAll('=', '_');
  }

  static String? parseFileToken(String token) {
    if (token.isEmpty) return null;
    return token.replaceAll('-', '/').replaceAll('.', '+').replaceAll('_', '=');
  }
}
