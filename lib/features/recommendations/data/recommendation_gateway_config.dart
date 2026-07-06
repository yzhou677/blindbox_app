/// Recommendation gateway configuration.
abstract final class RecommendationGatewayConfig {
  static const bool enableHttpGateway = bool.fromEnvironment(
    'RECOMMENDATION_GATEWAY_ENABLED',
    defaultValue: true,
  );

  static const String gatewayBaseUrl = String.fromEnvironment(
    'RECOMMENDATION_GATEWAY_BASE_URL',
    defaultValue:
        'https://us-central1-blindbox-collection.cloudfunctions.net/recommendations',
  );

  /// TTL for the local recommendations cache.
  /// Change here only — never hardcoded in repository or provider logic.
  static const Duration cacheTTL = Duration(hours: 2);

  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration profileSyncDebounce = Duration(seconds: 30);

  /// Curated For You rail length — short enough to feel hand-picked, not catalog-browse.
  static const int forYouResultLimit = 10;

  /// Share of slots filled from lower-ranked picks (rotates weekly). Rest = top stable.
  static const double forYouExplorationRatio = 0.2;

  static int forYouStableSlotCount([int limit = forYouResultLimit]) {
    return (limit * (1 - forYouExplorationRatio)).round();
  }

  static int forYouExplorationSlotCount([int limit = forYouResultLimit]) {
    return limit - forYouStableSlotCount(limit);
  }

  static const String readinessUnlockedKey = 'reco_readiness_unlocked_v1';
  static const String firstUnlockShownKey = 'reco_first_unlock_shown_v1';

  static Uri? get gatewayUri {
    final raw = gatewayBaseUrl.trim();
    if (raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  static bool get isHttpActive {
    if (!enableHttpGateway) return false;
    return gatewayUri != null;
  }
}
