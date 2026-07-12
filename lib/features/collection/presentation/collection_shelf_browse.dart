import 'package:blindbox_app/core/search/search_matcher.dart';
import 'package:blindbox_app/core/search/search_normalizer.dart';
import 'package:blindbox_app/core/search/search_tokenizer.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';

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
///
/// Prefer [catalogSearch] when the caller already holds a service for the
/// current bundle —avoids reconstructing indexes on every rebuild.
List<ShelfSeries> filterShelfSeriesBySearch(
  List<ShelfSeries> series,
  String query, {
  CatalogSeedBundle? catalog,
  CatalogSearchService? catalogSearch,
}) {
  final tokens = SearchTokenizer.tokenize(query);
  if (tokens.isEmpty) return series;

  final catalogSeriesIds = catalogSearch != null
      ? catalogSearch.matchingSeriesIds(query)
      : catalog != null
          ? CatalogSearchService(catalog).matchingSeriesIds(query)
          : const <String>{};

  final figureSeriesLookup = catalog != null && catalogSeriesIds.isNotEmpty
      ? _catalogFigureIdToSeriesId(catalog)
      : null;

  return [
    for (final row in series)
      if (_shelfSeriesMatchesSearch(
        row,
        tokens,
        catalogSeriesIds,
        figureSeriesLookup: figureSeriesLookup,
      ))
        row,
  ];
}

Map<String, String> _catalogFigureIdToSeriesId(CatalogSeedBundle catalog) {
  return {
    for (final fig in catalog.figures) fig.id: fig.seriesId,
  };
}

/// Catalog series ids a shelf row may represent (template key and drop imports).
Iterable<String> shelfCatalogSeriesIdCandidates(ShelfSeries series) sync* {
  final templateId = series.catalogTemplateId?.trim();
  if (templateId == null || templateId.isEmpty) return;
  yield templateId;
  final catalogId = recommendationCatalogSeriesId(series);
  if (catalogId != null && catalogId != templateId) {
    yield catalogId;
  }
}

bool _shelfSeriesMatchesSearch(
  ShelfSeries series,
  List<String> tokens,
  Set<String> catalogSeriesIds, {
  Map<String, String>? figureSeriesLookup,
}) {
  if (catalogSeriesIds.isNotEmpty) {
    for (final candidate in shelfCatalogSeriesIdCandidates(series)) {
      if (catalogSeriesIds.contains(candidate)) return true;
    }
    final lookup = figureSeriesLookup;
    if (lookup != null) {
      for (final fig in series.figures) {
        final templateId = fig.catalogFigureTemplateId?.trim();
        if (templateId == null || templateId.isEmpty) continue;
        final seriesId = lookup[templateId];
        if (seriesId != null && catalogSeriesIds.contains(seriesId)) {
          return true;
        }
      }
    }
  }
  return SearchMatcher.allTokensMatch(_shelfDisplayHaystack(series), tokens);
}

String _shelfDisplayHaystack(ShelfSeries series) {
  return [
    series.name,
    series.brand,
    shelfSeriesIpLabel(series),
  ].map(SearchNormalizer.normalizeForMatch).join(' ');
}

/// Whether all regular figures in [series] are owned — shelf Completed bucket rule.
bool isShelfSeriesComplete(
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
}) {
  return resolveSeriesCompletion(series, states).isCompleted;
}

/// Single-pass split into in-progress and completed buckets.
(List<ShelfSeries> inProgress, List<ShelfSeries> completed) partitionShelfSeries(
  List<ShelfSeries> series,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
}) {
  final inProgress = <ShelfSeries>[];
  final completed = <ShelfSeries>[];
  for (final row in series) {
    if (isShelfSeriesComplete(row, states, progress: progress)) {
      completed.add(row);
    } else {
      inProgress.add(row);
    }
  }
  return (inProgress, completed);
}

int _compareShelfSeriesByNameThenId(ShelfSeries a, ShelfSeries b) {
  final nameCmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (nameCmp != 0) return nameCmp;
  return a.id.compareTo(b.id);
}

double _seriesCompletionRatio(
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
}) {
  return resolveSeriesCompletion(series, states).progressRatio;
}

/// Display order for one bucket (In Progress or Completed) after filter/search.
///
/// The Collection rail is a **flat** series list. Sort modes operate on that
/// list only — no hidden IP grouping affects order.
///
/// ```text
/// Bucket → flat List<ShelfSeries> → one global comparator → render
/// ```
///
/// [CollectionShelfSort.recentlyAdded] preserves shelf traversal order within
/// the bucket.
///
/// See `docs/COLLECTION_ARCHITECTURE_NOTES.md` → Collection sorting.
List<ShelfSeries> sortShelfSeriesForDisplay(
  List<ShelfSeries> series,
  CollectionShelfSort sort,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
}) {
  switch (sort) {
    case CollectionShelfSort.recentlyAdded:
      return series;
    case CollectionShelfSort.alphabetical:
      return List<ShelfSeries>.from(series)
        ..sort(_compareShelfSeriesByNameThenId);
    case CollectionShelfSort.figureCount:
      return List<ShelfSeries>.from(series)
        ..sort((a, b) {
          final cmp = b.figureCount.compareTo(a.figureCount);
          if (cmp != 0) return cmp;
          return _compareShelfSeriesByNameThenId(a, b);
        });
    case CollectionShelfSort.completion:
      return List<ShelfSeries>.from(series)
        ..sort((a, b) {
          final cmp = _seriesCompletionRatio(b, states, progress: progress)
              .compareTo(
            _seriesCompletionRatio(a, states, progress: progress),
          );
          if (cmp != 0) return cmp;
          return _compareShelfSeriesByNameThenId(a, b);
        });
  }
}
