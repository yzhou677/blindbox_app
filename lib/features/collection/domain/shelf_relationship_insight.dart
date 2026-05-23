import 'package:flutter/foundation.dart';

enum ShelfRelationshipKind {
  sharedUniverse,
  lineupNeighbor,
  complementaryMood,
}

/// Lightweight pairwise shelf relationship (labels resolved in presentation).
@immutable
class ShelfRelationshipInsight {
  const ShelfRelationshipInsight({
    required this.kind,
    required this.primarySeriesId,
    required this.relatedSeriesId,
    this.taxonomyIpId,
    this.taxonomyBrandId,
  });

  final ShelfRelationshipKind kind;
  final String primarySeriesId;
  final String relatedSeriesId;
  final String? taxonomyIpId;
  final String? taxonomyBrandId;
}
