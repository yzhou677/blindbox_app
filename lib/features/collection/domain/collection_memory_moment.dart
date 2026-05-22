import 'package:flutter/foundation.dart';

/// Personal memory moments — calm, derived; not a social timeline.
enum CollectionMemoryMomentKind {
  firstSecretOwned,
  recentlyCompletedLineup,
  dominantUniverse,
  shelfMilestone,
  longLovedUniverse,
  shelfEvolution,
  shelfGrowing,
}

@immutable
class CollectionMemoryMoment {
  const CollectionMemoryMoment({
    required this.kind,
    this.seriesId,
    this.seriesName,
    this.taxonomyIpId,
    this.universeLabel,
    this.observedAt,
  });

  final CollectionMemoryMomentKind kind;
  final String? seriesId;
  final String? seriesName;
  final String? taxonomyIpId;
  final String? universeLabel;
  final DateTime? observedAt;
}
