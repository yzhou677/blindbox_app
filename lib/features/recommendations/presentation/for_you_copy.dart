import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';

abstract final class ForYouCopy {
  static const sectionTitle = 'For You';
  static const sectionSubtitle = 'Picked from your collection taste';
  static const firstUnlockBadge = 'New';
  static const firstUnlockSubtitle =
      "We've learned your collection taste.";
}

String forYouReason(String reasonType, String? meta) {
  return switch (reasonType) {
    RecommendationReasonType.ownedIp =>
      'Because you collect ${meta?.trim().isNotEmpty == true ? meta!.trim() : 'this IP'}',
    RecommendationReasonType.wishlistIp =>
      'Similar to your ${meta?.trim().isNotEmpty == true ? meta!.trim() : 'wishlist'} wishlist',
    RecommendationReasonType.recentRelease => 'New release',
    RecommendationReasonType.newInCatalog => 'New in catalog',
    _ => '',
  };
}
