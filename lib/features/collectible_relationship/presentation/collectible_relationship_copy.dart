import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_index.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_hint.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_kind.dart';

/// Calm editorial copy for relationship hints (no recommendation framing).
abstract final class CollectibleRelationshipCopy {
  static String? lineForHint({
    required CollectibleRelationshipHint hint,
    required CollectibleRelationshipIndex index,
  }) {
    return switch (hint.kind) {
      CollectibleRelationshipKind.shelfCompanion => _shelfCompanion(hint, index),
      CollectibleRelationshipKind.sharedUniverse => _sharedUniverse(hint, index),
      CollectibleRelationshipKind.adjacentUniverse =>
        'Often grouped with nearby collectible worlds',
      CollectibleRelationshipKind.lineupNeighbor =>
        _lineupNeighbor(hint, index),
      CollectibleRelationshipKind.catalogUniverseNeighbor =>
        _catalogNeighbor(hint, index),
      CollectibleRelationshipKind.moodCompanion =>
        'Collectors often pair this with other worlds from the same maker',
    };
  }

  static String? _shelfCompanion(
    CollectibleRelationshipHint hint,
    CollectibleRelationshipIndex index,
  ) {
    final name = hint.relatedSeriesId != null
        ? index.shelfSeriesName(hint.relatedSeriesId!)
        : null;
    if (name == null || name.isEmpty) {
      return 'Often sits beside another series on your shelf';
    }
    return 'Often sits beside $name on your shelf';
  }

  static String? _sharedUniverse(
    CollectibleRelationshipHint hint,
    CollectibleRelationshipIndex index,
  ) {
    final ipName = index.ipDisplayName(hint.taxonomyIpId);
    if (ipName != null && ipName.isNotEmpty) {
      return 'Shares the $ipName world with other series you collect';
    }
    final name = hint.relatedSeriesId != null
        ? index.shelfSeriesName(hint.relatedSeriesId!)
        : null;
    if (name != null && name.isNotEmpty) {
      return 'Shares a world with $name on your shelf';
    }
    return 'Part of a universe that keeps returning to your shelf';
  }

  static String? _catalogNeighbor(
    CollectibleRelationshipHint hint,
    CollectibleRelationshipIndex index,
  ) {
    final ipName = index.ipDisplayName(hint.taxonomyIpId);
    if (ipName != null && ipName.isNotEmpty) {
      return 'Nearby in the quiet $ipName world of collectibles';
    }
    final peer = hint.relatedSeriesId != null
        ? index.catalogSeriesName(hint.relatedSeriesId!)
        : null;
    if (peer != null && peer.isNotEmpty) {
      return 'Wanders near $peer in the catalog';
    }
    return 'Nearby in a connected collectible world';
  }

  static String? _lineupNeighbor(
    CollectibleRelationshipHint hint,
    CollectibleRelationshipIndex index,
  ) {
    final seriesId = hint.relatedSeriesId;
    final figureId = hint.relatedFigureId;
    if (seriesId == null || figureId == null) return null;
    final figures = index.lineupFiguresByCatalogSeriesId[seriesId];
    if (figures == null) return null;
    for (final f in figures) {
      if (f.figureId == figureId) {
        return 'Beside ${f.name} in this lineup';
      }
    }
    return 'Beside a neighboring figure in this lineup';
  }
}
