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
  });

  final String id;
  final String sourceId;
  final String sourceLabel;
  final String title;
  final String imageUrl;
  final String officialUrl;
  final DateTime publishedAt;
  final String contentHash;

  /// Optional short deck copy under the title (Firestore `summary`).
  final String? summary;
  final String? locale;
}
