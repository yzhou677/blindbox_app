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
      CollectibleRelationshipKind.shelfCompanion => _shelfCompanion(
        hint,
        index,
      ),
      CollectibleRelationshipKind.sharedUniverse => _sharedUniverse(
        hint,
        index,
      ),
      CollectibleRelationshipKind.adjacentUniverse =>
        'Adjacent catalog relationship detected',
      CollectibleRelationshipKind.lineupNeighbor => _lineupNeighbor(
        hint,
        index,
      ),
      CollectibleRelationshipKind.catalogUniverseNeighbor => _catalogNeighbor(
        hint,
        index,
      ),
      CollectibleRelationshipKind.moodCompanion =>
        'Same-maker relationship detected',
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
      return 'Shelf relationship detected';
    }
    return 'Shelf relationship with $name';
  }

  static String? _sharedUniverse(
    CollectibleRelationshipHint hint,
    CollectibleRelationshipIndex index,
  ) {
    final ipName = index.ipDisplayName(hint.taxonomyIpId);
    if (ipName != null && ipName.isNotEmpty) {
      return 'Shares the $ipName world with another recorded series';
    }
    final name = hint.relatedSeriesId != null
        ? index.shelfSeriesName(hint.relatedSeriesId!)
        : null;
    if (name != null && name.isNotEmpty) {
      return 'Shares a world with $name on your shelf';
    }
    return 'Shared-universe relationship detected';
  }

  static String? _catalogNeighbor(
    CollectibleRelationshipHint hint,
    CollectibleRelationshipIndex index,
  ) {
    final ipName = index.ipDisplayName(hint.taxonomyIpId);
    if (ipName != null && ipName.isNotEmpty) {
      return 'Part of the $ipName catalog universe';
    }
    final peer = hint.relatedSeriesId != null
        ? index.catalogSeriesName(hint.relatedSeriesId!)
        : null;
    if (peer != null && peer.isNotEmpty) {
      return 'Related catalog series: $peer';
    }
    return null;
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
