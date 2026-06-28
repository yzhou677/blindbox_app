import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_series_feed.dart';

/// Display-only sort modes for the Collection shelf browse pipeline.
enum CollectionShelfSort {
  recentlyAdded,
  alphabetical,
  figureCount,
  completion,
}

extension CollectionShelfSortLabels on CollectionShelfSort {
  String get menuLabel => switch (this) {
        CollectionShelfSort.recentlyAdded => 'Recently Added',
        CollectionShelfSort.alphabetical => 'Alphabetical (A–Z)',
        CollectionShelfSort.figureCount => 'Figure Count',
        CollectionShelfSort.completion => 'Completion',
      };

  static CollectionShelfSort? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in CollectionShelfSort.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Filters owned shelf rows using [CatalogSearchService] when [catalog] is
/// available, then falls back to display-field matching for custom rows or
/// when the bundle has not loaded.
///
/// Empty query returns [series] unchanged.
List<ShelfSeries> filterShelfSeriesBySearch(
  List<ShelfSeries> series,
  String query, {
  CatalogSeedBundle? catalog,
}) {
  final normalizedQuery = normalizeCatalogSearchQuery(query);
  if (normalizedQuery.isEmpty) return series;

  final catalogSeriesIds = catalog != null
      ? CatalogSearchService(catalog).matchingSeriesIds(query)
      : const <String>{};

  return [
    for (final row in series)
      if (_shelfSeriesMatchesSearch(row, normalizedQuery, catalogSeriesIds)) row,
  ];
}

bool _shelfSeriesMatchesSearch(
  ShelfSeries series,
  String normalizedQuery,
  Set<String> catalogSeriesIds,
) {
  final templateId = series.catalogTemplateId?.trim();
  if (templateId != null &&
      templateId.isNotEmpty &&
      catalogSeriesIds.contains(templateId)) {
    return true;
  }
  return _shelfDisplayFieldsMatch(series, normalizedQuery);
}

bool _shelfDisplayFieldsMatch(ShelfSeries series, String normalizedQuery) {
  for (final raw in [series.name, series.brand, shelfSeriesIpLabel(series)]) {
    final norm = normalizeCatalogSearchQuery(raw);
    if (norm.contains(normalizedQuery)) return true;
  }
  return false;
}

/// Whether every figure in [series] is owned — matches shelf card completion rule.
bool isShelfSeriesComplete(
  ShelfSeries series,
  Map<String, TrackedFigure> states,
) {
  final total = series.figureCount;
  if (total <= 0) return false;
  return progressForSeries(series, states).owned >= total;
}

/// Single-pass split into in-progress and completed buckets.
(List<ShelfSeries> inProgress, List<ShelfSeries> completed) partitionShelfSeries(
  List<ShelfSeries> series,
  Map<String, TrackedFigure> states,
) {
  final inProgress = <ShelfSeries>[];
  final completed = <ShelfSeries>[];
  for (final row in series) {
    if (isShelfSeriesComplete(row, states)) {
      completed.add(row);
    } else {
      inProgress.add(row);
    }
  }
  return (inProgress, completed);
}

/// Returns a display-ordered copy (or the same list for [recentlyAdded]).
List<ShelfSeries> sortShelfSeriesForDisplay(
  List<ShelfSeries> series,
  CollectionShelfSort sort,
  Map<String, TrackedFigure> states,
) {
  switch (sort) {
    case CollectionShelfSort.recentlyAdded:
      return series;
    case CollectionShelfSort.alphabetical:
      final sectionOrder = List<ShelfUniverseSection>.from(
        groupShelfSeriesByUniverse(series),
      )..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
      final ordered = <ShelfSeries>[];
      for (final section in sectionOrder) {
        final copy = List<ShelfSeries>.from(section.series)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        ordered.addAll(copy);
      }
      return ordered;
    case CollectionShelfSort.figureCount:
      final copy = List<ShelfSeries>.from(series);
      copy.sort((a, b) => b.figureCount.compareTo(a.figureCount));
      return copy;
    case CollectionShelfSort.completion:
      final copy = List<ShelfSeries>.from(series);
      copy.sort((a, b) {
        final aTotal = a.figureCount;
        final bTotal = b.figureCount;
        final aRatio = progressForSeries(a, states).completion(aTotal);
        final bRatio = progressForSeries(b, states).completion(bTotal);
        return bRatio.compareTo(aRatio);
      });
      return copy;
  }
}
