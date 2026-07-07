import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';

abstract final class ForYouCopy {
  static const sectionTitle = 'For You';
  static const sectionSubtitle = 'Picked from your collection taste';
  static const firstUnlockBadge = 'New';
  static const firstUnlockSubtitle =
      "We've learned your collection taste.";
}

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

String forYouSecondaryReason(String reasonType, String? meta) {
  return switch (reasonType) {
    RecommendationReasonType.recentRelease => '✨ New release',
    _ => forYouPrimaryReason(reasonType, meta),
  };
}

({String? primary, String? secondary}) forYouReasonLines(
  RecommendationItem item,
) {
  final primary = forYouPrimaryReason(
    item.primaryReasonType,
    item.primaryReasonMeta,
  );
  final secondaryType = item.secondaryReasonType;
  if (secondaryType == null) {
    return (primary: primary.isEmpty ? null : primary, secondary: null);
  }
  final secondary = forYouSecondaryReason(
    secondaryType,
    item.secondaryReasonMeta,
  );
  return (
    primary: primary.isEmpty ? null : primary,
    secondary: secondary.isEmpty ? null : secondary,
  );
}
