import 'package:flutter/foundation.dart';

/// One editorial official drop / announcement (external link).
@immutable
class OfficialFeedItem {
  const OfficialFeedItem({
    required this.id,
    required this.sourceId,
    required this.sourceLabel,
    required this.title,
    required this.imageUrl,
    required this.officialUrl,
    required this.publishedAt,
    required this.contentHash,
    this.summary,
    this.locale,
    this.releaseType,
    this.instagramUrl,
  });

  final String id;
  final String sourceId;
  final String sourceLabel;
  final String title;
  final String imageUrl;

  /// Preferred tap destination (product/storefront, or Instagram when no page).
  final String officialUrl;

  /// Optional Instagram announcement post for provenance.
  ///
  /// Used by clickable `via IG` only when [officialUrl] is not already
  /// Instagram (product/storefront cards).
  final String? instagramUrl;

  final DateTime publishedAt;
  final String contentHash;

  /// Optional short deck copy under the title (Firestore `summary`).
  final String? summary;
  final String? locale;

  /// Optional curator hint from seed push (`product`, `pop_now`, …).
  final String? releaseType;
}
