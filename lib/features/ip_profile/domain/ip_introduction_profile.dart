import 'package:flutter/foundation.dart';

/// User-facing rich IP introduction content (not catalog taxonomy [CatalogIp]).
///
/// Resolved strictly by stable `ipId` from `ip_profiles/{ipId}`.
@immutable
class IpIntroductionProfile {
  const IpIntroductionProfile({
    required this.ipId,
    required this.displayName,
    required this.shortDescription,
    required this.styleTags,
    this.creatorDisplayName,
    this.creatorBio,
  });

  /// Firestore document id / catalog series `ipId` — never a display label.
  final String ipId;

  final String displayName;
  final String shortDescription;

  /// Exactly three style tags when [isValidForIntroduction] is true.
  final List<String> styleTags;

  final String? creatorDisplayName;
  final String? creatorBio;

  bool get hasCreator {
    final name = creatorDisplayName?.trim() ?? '';
    final bio = creatorBio?.trim() ?? '';
    return name.isNotEmpty && bio.isNotEmpty;
  }

  /// Card may show the info icon only when this is true.
  bool get isValidForIntroduction {
    if (ipId.trim().isEmpty) return false;
    if (displayName.trim().isEmpty) return false;
    if (shortDescription.trim().isEmpty) return false;
    if (styleTags.length != 3) return false;
    for (final tag in styleTags) {
      if (tag.trim().isEmpty) return false;
    }
    return true;
  }
}

/// IP-level Collection summary for the introduction sheet (series count only).
@immutable
class IpIntroductionIpSeriesCount {
  const IpIntroductionIpSeriesCount({required this.seriesCount})
    : assert(seriesCount > 0);

  /// Distinct Collection Series sharing this profile's stable `ipId`.
  final int seriesCount;

  /// Preferred copy: `1 series` / `4 series` (word unchanged for plural).
  String get seriesLine => '$seriesCount series';
}
