import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_kind.dart';
import 'package:flutter/foundation.dart';

/// A single calm relationship surface (at most one shown per focal view).
@immutable
class CollectibleRelationshipHint {
  const CollectibleRelationshipHint({
    required this.kind,
    this.relatedSeriesId,
    this.relatedFigureId,
    this.taxonomyIpId,
    this.taxonomyBrandId,
    this.focalSeriesId,
    this.focalFigureId,
  });

  final CollectibleRelationshipKind kind;
  final String? relatedSeriesId;
  final String? relatedFigureId;
  final String? taxonomyIpId;
  final String? taxonomyBrandId;
  final String? focalSeriesId;
  final String? focalFigureId;
}

/// Keys for resolving a relationship around a catalog figure, shelf row, or market sighting.
@immutable
class CollectibleRelationshipFocal {
  const CollectibleRelationshipFocal({
    this.shelfSeriesId,
    this.catalogSeriesId,
    this.figureId,
    this.taxonomyIpId,
    this.taxonomyBrandId,
  });

  final String? shelfSeriesId;
  final String? catalogSeriesId;
  final String? figureId;
  final String? taxonomyIpId;
  final String? taxonomyBrandId;
}
