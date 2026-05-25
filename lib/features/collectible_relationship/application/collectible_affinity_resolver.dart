import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_index.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_hint.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_kind.dart';

/// Picks at most one editorial relationship hint for a focal collectible context.
CollectibleRelationshipHint? resolveCollectibleRelationshipHint({
  required CollectibleRelationshipFocal focal,
  required CollectibleRelationshipIndex index,
}) {
  final ip = focal.taxonomyIpId?.trim();
  final brand = focal.taxonomyBrandId?.trim();
  final shelfId = focal.shelfSeriesId?.trim();
  final catalogId = focal.catalogSeriesId?.trim();
  final figureId = focal.figureId?.trim();

  if (shelfId != null && shelfId.isNotEmpty && ip != null && ip.isNotEmpty) {
    final peers = index.shelfSeriesIdsByIp[ip] ?? const [];
    for (final peerId in peers) {
      if (peerId == shelfId) continue;
      return CollectibleRelationshipHint(
        kind: CollectibleRelationshipKind.shelfCompanion,
        relatedSeriesId: peerId,
        taxonomyIpId: ip,
        focalSeriesId: shelfId,
      );
    }
  }

  if (figureId != null &&
      figureId.isNotEmpty &&
      catalogId != null &&
      catalogId.isNotEmpty) {
    final neighbor = _lineupNeighbor(
      index: index,
      catalogSeriesId: catalogId,
      figureId: figureId,
    );
    if (neighbor != null) {
      return CollectibleRelationshipHint(
        kind: CollectibleRelationshipKind.lineupNeighbor,
        relatedFigureId: neighbor.figureId,
        relatedSeriesId: catalogId,
        focalFigureId: figureId,
        focalSeriesId: shelfId,
      );
    }
  }

  if (brand != null && brand.isNotEmpty) {
    final ips = index.shelfIpsByBrand[brand];
    if (ips != null && ips.length >= 2) {
      final focalIp = ip;
      String? otherIp;
      for (final candidate in ips) {
        if (focalIp == null || focalIp.isEmpty || candidate != focalIp) {
          otherIp = candidate;
          break;
        }
      }
      if (otherIp != null) {
        final relatedShelf = index.shelfSeriesIdsByIp[otherIp]?.firstOrNull;
        return CollectibleRelationshipHint(
          kind: CollectibleRelationshipKind.moodCompanion,
          relatedSeriesId: relatedShelf,
          taxonomyBrandId: brand,
          taxonomyIpId: focalIp,
          focalSeriesId: shelfId,
        );
      }
    }
  }

  if (ip != null && ip.isNotEmpty) {
    final catalogPeers = index.catalogSeriesIdsByIp[ip] ?? const [];
    for (final peerCatalogId in catalogPeers) {
      final onShelf = index.shelfSeriesIds.any(
        (id) => index.shelfSeriesById[id]?.catalogTemplateId == peerCatalogId,
      );
      if (onShelf) continue;
      if (catalogId != null && peerCatalogId == catalogId) continue;
      return CollectibleRelationshipHint(
        kind: CollectibleRelationshipKind.catalogUniverseNeighbor,
        relatedSeriesId: peerCatalogId,
        taxonomyIpId: ip,
        focalSeriesId: shelfId,
      );
    }

    if (shelfId != null) {
      final peers = index.shelfSeriesIdsByIp[ip] ?? const [];
      if (peers.length >= 2) {
        final related = peers.firstWhere(
          (id) => id != shelfId,
          orElse: () => '',
        );
        if (related.isNotEmpty) {
          return CollectibleRelationshipHint(
            kind: CollectibleRelationshipKind.sharedUniverse,
            relatedSeriesId: related,
            taxonomyIpId: ip,
            focalSeriesId: shelfId,
          );
        }
      }
    }
  }

  if (brand != null &&
      brand.isNotEmpty &&
      ip != null &&
      ip.isNotEmpty &&
      (index.shelfIpsByBrand[brand]?.length ?? 0) >= 2) {
    return CollectibleRelationshipHint(
      kind: CollectibleRelationshipKind.adjacentUniverse,
      taxonomyBrandId: brand,
      taxonomyIpId: ip,
      focalSeriesId: shelfId,
    );
  }

  return null;
}

({String figureId})? _lineupNeighbor({
  required CollectibleRelationshipIndex index,
  required String catalogSeriesId,
  required String figureId,
}) {
  final figures = index.lineupFiguresByCatalogSeriesId[catalogSeriesId];
  if (figures == null || figures.length < 2) return null;

  var idx = -1;
  for (var i = 0; i < figures.length; i++) {
    if (figures[i].figureId == figureId) {
      idx = i;
      break;
    }
  }
  if (idx < 0) return null;

  final neighborIdx = idx == 0 ? 1 : idx - 1;
  if (neighborIdx == idx || neighborIdx >= figures.length) return null;
  return (figureId: figures[neighborIdx].figureId);
}
