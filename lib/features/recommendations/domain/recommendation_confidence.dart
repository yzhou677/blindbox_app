import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';

enum RecommendationConfidence {
  none,
  low,
  medium,
  high,
}

/// Readiness threshold — adjust without changing provider logic.
const RecommendationConfidence recommendationReadinessThreshold =
    RecommendationConfidence.low;

int recommendationConfidenceRank(RecommendationConfidence confidence) {
  return switch (confidence) {
    RecommendationConfidence.none => 0,
    RecommendationConfidence.low => 1,
    RecommendationConfidence.medium => 2,
    RecommendationConfidence.high => 3,
  };
}

RecommendationConfidence computeConfidence(PreferenceSignals signals) {
  if (signals.ownedCatalogSeriesCount >= 5) {
    return RecommendationConfidence.high;
  }
  if (signals.ownedCatalogSeriesCount >= 3) {
    return RecommendationConfidence.medium;
  }
  if (signals.ownedCatalogSeriesCount >= 1 ||
      signals.wishlistCatalogSeriesCount >= 5) {
    return RecommendationConfidence.low;
  }
  return RecommendationConfidence.none;
}

bool isRecommendationReady(PreferenceSignals signals) {
  return recommendationConfidenceRank(computeConfidence(signals)) >=
      recommendationConfidenceRank(recommendationReadinessThreshold);
}
