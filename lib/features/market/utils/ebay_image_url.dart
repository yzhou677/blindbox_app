/// eBay CDN image URL helpers — client-side fallback when gateway rows are stale.
enum EbayImageSize {
  browse,
  detail,
}

String upgradeEbayImageUrl(String url, {EbayImageSize size = EbayImageSize.browse}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;

  final target = size == EbayImageSize.detail ? 's-l1600' : 's-l500';
  final pattern = RegExp(r'/s-l\d+\.', caseSensitive: false);
  if (pattern.hasMatch(trimmed)) {
    return trimmed.replaceFirst(pattern, '/$target.');
  }
  return trimmed;
}

/// Reconstruct Browse `itemId` (`v1|{legacy}|0`) from a stable legacy id.
String ebayBrowseItemId(String providerListingId) {
  final trimmed = providerListingId.trim();
  if (trimmed.contains('|')) return trimmed;
  return 'v1|$trimmed|0';
}
