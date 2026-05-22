/// Taxonomy-grounded relationship kinds (derived, not ML-ranked).
enum CollectibleRelationshipKind {
  /// Another series on the user's shelf shares universe or brand context.
  shelfCompanion,

  /// Same IP / universe across shelf or catalog.
  sharedUniverse,

  /// Same brand, distinct universes the collector tends to group.
  adjacentUniverse,

  /// Neighboring figure slot in a catalog lineup.
  lineupNeighbor,

  /// Another catalog series in the same IP not yet on shelf.
  catalogUniverseNeighbor,

  /// Shelf spans complementary moods under one maker.
  moodCompanion,
}
