import 'package:flutter/foundation.dart';

/// Foundation memory moments — no timeline UI in Phase 4.
enum CollectionMemoryMomentKind {
  firstSecretOwned,
  recentlyCompletedLineup,
  dominantUniverse,
  shelfMilestone,
}

@immutable
class CollectionMemoryMoment {
  const CollectionMemoryMoment({
    required this.kind,
    this.seriesId,
    this.seriesName,
    this.taxonomyIpId,
    this.observedAt,
  });

  final CollectionMemoryMomentKind kind;
  final String? seriesId;
  final String? seriesName;
  final String? taxonomyIpId;
  final DateTime? observedAt;
}
