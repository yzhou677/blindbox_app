import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

/// POP MART site logo / favicon — never a per-item release image.
bool _isPopMartPlaceholderImage(String imageUrl) {
  final lower = imageUrl.toLowerCase();
  return lower.contains('/images/192.png') ||
      lower.contains('favicon.ico') ||
      lower.contains('/images/logo');
}

bool _hostMatches(Uri uri, String rootHost) {
  final host = uri.host.toLowerCase();
  return host == rootHost || host.endsWith('.$rootHost');
}

/// Rejects storefront home (`/us`) when a product link exists in seed.
bool _isPopMartUsHomepage(Uri uri) {
  if (!_hostMatches(uri, 'popmart.com')) return false;
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return path.isEmpty || path == '/us';
}

/// `/us/products/{numericId}/…` — slug-only paths break POP MART client routing.
bool _isPopMartUsNumericProductPath(Uri uri) {
  final match = RegExp(r'^/us/products/([^/]+)').firstMatch(uri.path);
  if (match == null) return false;
  return RegExp(r'^\d+$').hasMatch(match.group(1)!);
}

/// Product, POP NOW set, or numbered collection — not the US landing page.
bool _isPopMartUsItemPath(Uri uri) {
  if (!_hostMatches(uri, 'popmart.com')) return false;
  final path = uri.path;
  if (path.startsWith('/us/products/')) {
    return _isPopMartUsNumericProductPath(uri);
  }
  if (path.startsWith('/us/pop-now/')) {
    final rest = path.substring('/us/pop-now/'.length);
    return rest.isNotEmpty;
  }
  if (path.startsWith('/us/collection/')) {
    return RegExp(r'^/us/collection/\d+').hasMatch(path);
  }
  return false;
}

/// Official Instagram post (`/p/`, `/reel/`, `/tv/`).
bool isOfficialInstagramPostUrl(Uri uri) {
  if (!_hostMatches(uri, 'instagram.com')) return false;
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return RegExp(r'^/(p|reel|tv)/[^/]+').hasMatch(path);
}

/// Non-homepage HTTPS path on an allowed brand storefront host.
bool _isBrandStorefrontItemPath(Uri uri, List<String> rootHosts) {
  if (!rootHosts.any((h) => _hostMatches(uri, h))) return false;
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (path.isEmpty) return false;
  // Bare locale / region roots are discovery hubs, not feed destinations.
  if (RegExp(
    r'^/(us|en|zh|sg|my|jp|hk|tw)?$',
    caseSensitive: false,
  ).hasMatch(path)) {
    return false;
  }
  return true;
}

bool _isTntSpaceItemPath(Uri uri) =>
    _isBrandStorefrontItemPath(uri, const ['tntspace.com']);

bool _isTopToyItemPath(Uri uri) =>
    _isBrandStorefrontItemPath(uri, const ['gotoptoy.com', 'toptoyglobal.com']);

bool _isSonnyAngelItemPath(Uri uri) => _isBrandStorefrontItemPath(uri, const [
  'sonnyangel.com',
  'sonnyangelstore.com',
]);

/// Destination rules keyed by curated [sourceId] (Instagram allowed for all
/// **known** brands only).
bool isValidOfficialFeedDestination(Uri uri, String sourceId) {
  if (!OfficialFeedSources.curatedHomeSources.contains(sourceId)) {
    return false;
  }
  if (isOfficialInstagramPostUrl(uri)) return true;
  return switch (sourceId) {
    OfficialFeedSources.popmartUs => _isPopMartUsItemPath(uri),
    OfficialFeedSources.tntspaceUs => _isTntSpaceItemPath(uri),
    OfficialFeedSources.toptoyUs => _isTopToyItemPath(uri),
    OfficialFeedSources.sonnyangelUs => _isSonnyAngelItemPath(uri),
    _ => false,
  };
}

/// Valid optional provenance Instagram URL, or null when absent/invalid.
String? parseOfficialFeedInstagramUrl(String? raw) {
  if (!_hasText(raw)) return null;
  final uri = Uri.tryParse(raw!.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      !isOfficialInstagramPostUrl(uri)) {
    return null;
  }
  return uri.toString();
}

DateTime? _readPublishedAt(Map<String, dynamic> data) {
  final raw = data['publishedAt'];
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}

/// Maps a Firestore document to [OfficialFeedItem], or null when invalid.
OfficialFeedItem? mapOfficialFeedItem(String docId, Map<String, dynamic> data) {
  final id = _hasText(data['id'] as String?)
      ? (data['id'] as String).trim()
      : docId;
  final sourceId = (data['sourceId'] as String?)?.trim() ?? '';
  final sourceLabel = (data['sourceLabel'] as String?)?.trim() ?? '';
  final title = (data['title'] as String?)?.trim() ?? '';
  final imageUrl = (data['imageUrl'] as String?)?.trim() ?? '';
  final officialUrl = (data['officialUrl'] as String?)?.trim() ?? '';
  final contentHash = (data['contentHash'] as String?)?.trim() ?? '';
  final status = (data['status'] as String?)?.trim() ?? '';
  final publishedAt = _readPublishedAt(data);

  if (!_hasText(sourceId) ||
      !_hasText(sourceLabel) ||
      !_hasText(title) ||
      !_hasText(imageUrl) ||
      !_hasText(officialUrl) ||
      !_hasText(contentHash) ||
      publishedAt == null) {
    return null;
  }

  if (status != 'active') {
    return null;
  }

  final uri = Uri.tryParse(officialUrl);
  final imageUri = Uri.tryParse(imageUrl);
  if (uri == null ||
      uri.scheme != 'https' ||
      imageUri == null ||
      imageUri.scheme != 'https') {
    return null;
  }

  if (_isPopMartPlaceholderImage(imageUrl) ||
      _isPopMartUsHomepage(uri) ||
      !isValidOfficialFeedDestination(uri, sourceId)) {
    return null;
  }

  final locale = (data['locale'] as String?)?.trim();
  final summary = (data['summary'] as String?)?.trim();
  final releaseType = (data['releaseType'] as String?)?.trim();
  final instagramUrl = parseOfficialFeedInstagramUrl(
    data['instagramUrl'] as String?,
  );

  return OfficialFeedItem(
    id: id,
    sourceId: sourceId,
    sourceLabel: sourceLabel,
    title: title,
    imageUrl: imageUrl,
    officialUrl: officialUrl,
    publishedAt: publishedAt,
    contentHash: contentHash,
    summary: summary?.isNotEmpty == true ? summary : null,
    locale: locale?.isNotEmpty == true ? locale : null,
    releaseType: releaseType?.isNotEmpty == true ? releaseType : null,
    instagramUrl: instagramUrl,
  );
}
