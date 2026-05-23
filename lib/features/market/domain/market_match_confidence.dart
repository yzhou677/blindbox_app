/// Deterministic confidence tier for catalog identity matching (data layer only).
enum MarketMatchConfidence {
  none,
  low,
  medium,
  high,
  exact,
}

extension MarketMatchConfidenceX on MarketMatchConfidence {
  /// Numeric ordering for comparisons (higher = more confident).
  int get rank => index;

  bool get isResolved => this != MarketMatchConfidence.none;

  /// Filter chips may use brand/IP when at least [low].
  bool get usableForTaxonomyFilters => rank >= MarketMatchConfidence.low.rank;
}
