/// Confidence in grouping multiple listings into one collectible surface.
enum AggregationConfidence {
  none,
  low,
  medium,
  high,
}

extension AggregationConfidenceX on AggregationConfidence {
  int get rank => index;
}
