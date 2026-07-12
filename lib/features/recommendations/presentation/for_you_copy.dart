import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';

abstract final class ForYouCopy {
  static const sectionTitle = 'For You';
  static const sectionSubtitle = 'Picked from your collection taste';
  static const firstUnlockBadge = 'New';
  static const firstUnlockSubtitle =
      "We've learned your collection taste.";
}

/// Deterministic display priority — lower index wins.
///
/// One card, one story. Personalized collection reasons beat freshness tags.
const List<String> kForYouReasonDisplayPriority = [
  RecommendationReasonType.trackedIp,
  'owned_ip', // legacy alias
  RecommendationReasonType.wishlistIp,
  // Future: collector_type
  // Future: trending
  RecommendationReasonType.recentRelease,
  RecommendationReasonType.newInCatalog,
];

String forYouReason(String reasonType, String? meta) =>
    forYouPrimaryReason(reasonType, meta);

String forYouPrimaryReason(String reasonType, String? meta) {
  final ipLabel = meta?.trim().isNotEmpty == true ? meta!.trim() : 'this IP';
  return switch (reasonType) {
    RecommendationReasonType.trackedIp || 'owned_ip' => 'Collecting $ipLabel',
    RecommendationReasonType.wishlistIp =>
      'Similar to your ${meta?.trim().isNotEmpty == true ? meta!.trim() : 'wishlist'} wishlist',
    RecommendationReasonType.recentRelease => '✨ New release',
    RecommendationReasonType.newInCatalog => 'Discover something new',
    _ => '',
  };
}

/// Single card story — highest-priority reason among primary + secondary.
///
/// Suppresses stacked tags (e.g. Collecting Dimoo + New release) so artwork
/// stays the visual focus.
String? forYouCardReason(RecommendationItem item) {
  final candidates = <({String type, String? meta})>[
    (type: item.primaryReasonType, meta: item.primaryReasonMeta),
    if (item.secondaryReasonType != null)
      (type: item.secondaryReasonType!, meta: item.secondaryReasonMeta),
  ];

  ({String type, String? meta})? best;
  var bestRank = 1 << 30;
  for (final candidate in candidates) {
    final rank = _reasonDisplayRank(candidate.type);
    if (rank < bestRank) {
      bestRank = rank;
      best = candidate;
    }
  }
  if (best == null) return null;
  final copy = forYouPrimaryReason(best.type, best.meta);
  return copy.isEmpty ? null : copy;
}

int _reasonDisplayRank(String reasonType) {
  final index = kForYouReasonDisplayPriority.indexOf(reasonType);
  return index < 0 ? kForYouReasonDisplayPriority.length + 100 : index;
}

/// @Deprecated Prefer [forYouCardReason]. Secondary is always null — one story.
({String? primary, String? secondary}) forYouReasonLines(
  RecommendationItem item,
) {
  return (primary: forYouCardReason(item), secondary: null);
}
