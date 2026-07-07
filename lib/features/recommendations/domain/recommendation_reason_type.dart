/// Stable reason codes returned by the recommendation engine.
///
/// User-facing copy is generated client-side from [reasonType] + [reasonMeta].
abstract final class RecommendationReasonType {
  static const trackedIp = 'tracked_ip';
  static const wishlistIp = 'wishlist_ip';
  static const recentRelease = 'recent_release';
  static const newInCatalog = 'new_in_catalog';
}
