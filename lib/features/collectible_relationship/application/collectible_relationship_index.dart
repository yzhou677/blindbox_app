import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart' as seed_fig;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/foundation.dart';

/// Minimal figure row for lineup-adjacency (catalog sort order).
@immutable
class LineupFigureRef {
  const LineupFigureRef({required this.figureId, required this.name});

  final String figureId;
  final String name;
}

/// Offline index for deterministic collectible adjacency (shelf + catalog).
@immutable
class CollectibleRelationshipIndex {
  const CollectibleRelationshipIndex({
    required this.shelfSeriesIds,
    required this.shelfSeriesById,
    required this.shelfSeriesIdsByIp,
    required this.shelfIpsByBrand,
    required this.catalogSeriesIdsByIp,
    required this.catalogSeriesNameById,
    required this.lineupFiguresByCatalogSeriesId,
    required this.catalogIpNameById,
  });

  final Set<String> shelfSeriesIds;
  final Map<String, ShelfSeries> shelfSeriesById;
  final Map<String, List<String>> shelfSeriesIdsByIp;
  final Map<String, Set<String>> shelfIpsByBrand;
  final Map<String, List<String>> catalogSeriesIdsByIp;
  final Map<String, String> catalogSeriesNameById;
  final Map<String, List<LineupFigureRef>> lineupFiguresByCatalogSeriesId;
  final Map<String, String> catalogIpNameById;

  factory CollectibleRelationshipIndex.fromShelfAndCatalog({
    required CollectionSnapshot snap,
    CatalogSeedBundle? catalog,
  }) {
    final shelfSeriesById = <String, ShelfSeries>{};
    final shelfSeriesIdsByIp = <String, List<String>>{};
    final shelfIpsByBrand = <String, Set<String>>{};

    for (final series in snap.shelfSeries) {
      shelfSeriesById[series.id] = series;
      final ip = series.taxonomyIpId?.trim();
      if (ip != null && ip.isNotEmpty) {
        shelfSeriesIdsByIp.putIfAbsent(ip, () => []).add(series.id);
      }
      final brand = series.taxonomyBrandId?.trim();
      if (brand != null && brand.isNotEmpty && ip != null && ip.isNotEmpty) {
        shelfIpsByBrand.putIfAbsent(brand, () => {}).add(ip);
      }
    }

    final catalogSeriesIdsByIp = <String, List<String>>{};
    final catalogSeriesNameById = <String, String>{};
    final lineupFiguresByCatalogSeriesId = <String, List<LineupFigureRef>>{};
    final catalogIpNameById = <String, String>{};

    if (catalog != null) {
      for (final ip in catalog.ips) {
        catalogIpNameById[ip.id] = ip.displayName;
      }
      for (final s in catalog.series) {
        catalogSeriesNameById[s.id] = s.displayName;
        catalogSeriesIdsByIp.putIfAbsent(s.ipId, () => []).add(s.id);
      }
      for (final ipEntry in catalogSeriesIdsByIp.entries) {
        ipEntry.value.sort();
      }
      final figuresBySeries = <String, List<seed_fig.CatalogFigure>>{};
      for (final f in catalog.figures) {
        figuresBySeries.putIfAbsent(f.seriesId, () => []).add(f);
      }
      for (final entry in figuresBySeries.entries) {
        final sorted = List<seed_fig.CatalogFigure>.from(entry.value)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        lineupFiguresByCatalogSeriesId[entry.key] = [
          for (final fig in sorted)
            LineupFigureRef(figureId: fig.id, name: fig.displayName),
        ];
      }
    }

    return CollectibleRelationshipIndex(
      shelfSeriesIds: shelfSeriesById.keys.toSet(),
      shelfSeriesById: shelfSeriesById,
      shelfSeriesIdsByIp: shelfSeriesIdsByIp,
      shelfIpsByBrand: shelfIpsByBrand,
      catalogSeriesIdsByIp: catalogSeriesIdsByIp,
      catalogSeriesNameById: catalogSeriesNameById,
      lineupFiguresByCatalogSeriesId: lineupFiguresByCatalogSeriesId,
      catalogIpNameById: catalogIpNameById,
    );
  }

  String? shelfSeriesName(String seriesId) =>
      shelfSeriesById[seriesId]?.name;

  String? catalogSeriesName(String seriesId) =>
      catalogSeriesNameById[seriesId];

  String? ipDisplayName(String? ipId) {
    if (ipId == null || ipId.isEmpty) return null;
    return catalogIpNameById[ipId];
  }
}
