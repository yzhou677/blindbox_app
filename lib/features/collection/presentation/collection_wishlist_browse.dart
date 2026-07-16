import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';

enum CollectionWishlistSort { recentlyAdded, alphabetical }

extension CollectionWishlistSortLabels on CollectionWishlistSort {
  String get menuLabel => switch (this) {
    CollectionWishlistSort.recentlyAdded => 'Recently Added',
    CollectionWishlistSort.alphabetical => 'Alphabetical (A-Z)',
  };
}

typedef WishlistBrandFilterOption = ({String id, String label});
typedef WishlistIpFilterOption = ({String id, String label});

final class WishlistedFigureRow {
  const WishlistedFigureRow({
    required this.figure,
    required this.series,
    required this.tracked,
  });

  final ShelfFigure figure;
  final ShelfSeries series;
  final TrackedFigure tracked;
}

List<WishlistedFigureRow> wishlistedFigureRows(CollectionSnapshot snapshot) {
  final rows = <WishlistedFigureRow>[];
  for (final series in snapshot.shelfSeries) {
    for (final figure in series.figures) {
      final tracked = snapshot.figureStates[figure.id];
      if (tracked?.wishlist != true) continue;
      rows.add(
        WishlistedFigureRow(figure: figure, series: series, tracked: tracked!),
      );
    }
  }
  return rows;
}

List<WishlistBrandFilterOption> buildWishlistBrandFilterOptions(
  List<WishlistedCatalogSeries> series,
  List<WishlistedFigureRow> figures,
) {
  final options = <WishlistBrandFilterOption>[
    (id: collectionAnyBrandFilterId, label: 'All Brands'),
  ];
  final seen = <String>{collectionAnyBrandFilterId};
  void add(String id, String label) {
    final key = normalizeCollectionFacetFilterKey(id);
    if (key.isEmpty || seen.contains(key)) return;
    options.add((id: key, label: label.trim().isNotEmpty ? label.trim() : key));
    seen.add(key);
  }

  for (final item in series) {
    add(item.brand, item.brand);
  }
  for (final row in figures) {
    add(row.series.brand, row.series.brand);
  }
  return options;
}

List<WishlistIpFilterOption> buildWishlistIpFilterOptions(
  List<WishlistedCatalogSeries> series,
  List<WishlistedFigureRow> figures,
) {
  final options = <WishlistIpFilterOption>[
    (id: collectionAnyIpFilterId, label: 'All IPs'),
  ];
  final seen = <String>{collectionAnyIpFilterId};
  void add(String id, String label) {
    final key = normalizeCollectionFacetFilterKey(id);
    if (key.isEmpty || seen.contains(key)) return;
    options.add((id: key, label: label.trim().isNotEmpty ? label.trim() : key));
    seen.add(key);
  }

  for (final item in series) {
    add(item.ipName, item.ipName);
  }
  for (final row in figures) {
    add(shelfSeriesIpLabel(row.series), shelfSeriesIpLabel(row.series));
  }
  return options;
}

List<WishlistedCatalogSeries> filterWishlistSeries({
  required List<WishlistedCatalogSeries> series,
  required String query,
  required String brandFilterId,
  required String ipFilterId,
}) {
  final q = normalizeCatalogSearchQuery(query);
  return [
    for (final item in series)
      if (_matchesFacet(
            brandFilterId,
            item.brand,
            collectionAnyBrandFilterId,
          ) &&
          _matchesFacet(ipFilterId, item.ipName, collectionAnyIpFilterId) &&
          _matchesQuery(q, [item.name, item.brand, item.ipName]))
        item,
  ];
}

List<WishlistedFigureRow> filterWishlistFigures({
  required List<WishlistedFigureRow> figures,
  required String query,
  required String brandFilterId,
  required String ipFilterId,
}) {
  final q = normalizeCatalogSearchQuery(query);
  return [
    for (final row in figures)
      if (_matchesFacet(
            brandFilterId,
            row.series.brand,
            collectionAnyBrandFilterId,
          ) &&
          _matchesFacet(
            ipFilterId,
            shelfSeriesIpLabel(row.series),
            collectionAnyIpFilterId,
          ) &&
          _matchesQuery(q, [
            row.figure.name,
            row.series.name,
            row.series.brand,
            shelfSeriesIpLabel(row.series),
          ]))
        row,
  ];
}

List<WishlistedCatalogSeries> sortWishlistSeries(
  List<WishlistedCatalogSeries> series,
  CollectionWishlistSort sort,
) {
  final next = List<WishlistedCatalogSeries>.from(series);
  switch (sort) {
    case CollectionWishlistSort.recentlyAdded:
      next.sort((a, b) => b.addedAtMicros.compareTo(a.addedAtMicros));
    case CollectionWishlistSort.alphabetical:
      next.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return next;
}

List<WishlistedFigureRow> sortWishlistFigures(
  List<WishlistedFigureRow> figures,
  CollectionWishlistSort sort,
) {
  final next = List<WishlistedFigureRow>.from(figures);
  switch (sort) {
    case CollectionWishlistSort.recentlyAdded:
      next.sort((a, b) {
        final byTime = (b.tracked.updatedAtMicros ?? 0).compareTo(
          a.tracked.updatedAtMicros ?? 0,
        );
        if (byTime != 0) return byTime;
        return a.figure.name.toLowerCase().compareTo(
          b.figure.name.toLowerCase(),
        );
      });
    case CollectionWishlistSort.alphabetical:
      next.sort(
        (a, b) =>
            a.figure.name.toLowerCase().compareTo(b.figure.name.toLowerCase()),
      );
  }
  return next;
}

bool _matchesFacet(String selected, String rawValue, String anyId) {
  if (selected == anyId) return true;
  return normalizeCollectionFacetFilterKey(rawValue) == selected;
}

bool _matchesQuery(String normalizedQuery, List<String> fields) {
  if (normalizedQuery.isEmpty) return true;
  return fields.any(
    (field) => normalizeCatalogSearchQuery(field).contains(normalizedQuery),
  );
}
