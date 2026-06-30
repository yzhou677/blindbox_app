import 'package:blindbox_app/core/search/search_matcher.dart';
import 'package:blindbox_app/core/search/search_normalizer.dart';
import 'package:blindbox_app/core/search/search_tokenizer.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
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
        CollectionShelfSort.alphabetical => 'Alphabetical (A?�Z)',
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

  return [
    for (final row in series)
      if (_shelfSeriesMatchesSearch(row, tokens, catalogSeriesIds)) row,
  ];
}

bool _shelfSeriesMatchesSearch(
  ShelfSeries series,
  List<String> tokens,
  Set<String> catalogSeriesIds,
) {
  final templateId = series.catalogTemplateId?.trim();
  if (templateId != null &&
      templateId.isNotEmpty &&
      catalogSeriesIds.contains(templateId)) {
    return true;
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

SeriesProgressCounts _seriesProgress(
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
}) =>
    progress?.forSeries(series) ?? progressForSeries(series, states);

/// Whether every figure in [series] is owned —matches shelf card completion rule.
bool isShelfSeriesComplete(
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
}) {
  final total = series.figureCount;
  if (total <= 0) return false;
  return _seriesProgress(series, states, progress: progress).owned >= total;
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

int _ipFigureCountTotal(ShelfUniverseSection section) =>
    section.series.fold<int>(0, (sum, row) => sum + row.figureCount);

/// Owned figures / total figure slots across every series in the IP group.
double _ipWeightedCompletion(
  ShelfUniverseSection section,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
}) {
  var owned = 0;
  var total = 0;
  for (final row in section.series) {
    final slots = row.figureCount;
    if (slots <= 0) continue;
    total += slots;
    owned += _seriesProgress(row, states, progress: progress).owned;
  }
  if (total <= 0) return 0;
  return owned / total;
}

int _compareIpSectionLabels(ShelfUniverseSection a, ShelfUniverseSection b) {
  final labelCmp =
      a.label.toLowerCase().compareTo(b.label.toLowerCase());
  if (labelCmp != 0) return labelCmp;
  return a.key.compareTo(b.key);
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
  final total = series.figureCount;
  return _seriesProgress(series, states, progress: progress).completion(total);
}

/// Display order for one bucket (In Progress or Completed) after filter/search.
///
/// The Collection page is a hierarchical browser, not a flat ranked list.
///
/// ```text
/// Bucket ??IP ??Series
/// ```
///
/// Every sort mode defines an IP aggregate and a series aggregate (see
/// `docs/COLLECTION_ARCHITECTURE_NOTES.md` ??Collection sorting reference).
/// The feed builder only renders that order.
///
/// [CollectionShelfSort.recentlyAdded] preserves shelf traversal order within
/// the bucket (IP blocks follow encounter order when regrouped for display).
///
/// Future sort modes should follow this model unless Product intentionally
/// introduces a flat ranked list.
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
      final sectionOrder = List<ShelfUniverseSection>.from(
        groupShelfSeriesByUniverse(series),
      )..sort(_compareIpSectionLabels);
      final ordered = <ShelfSeries>[];
      for (final section in sectionOrder) {
        final copy = List<ShelfSeries>.from(section.series)
          ..sort(_compareShelfSeriesByNameThenId);
        ordered.addAll(copy);
      }
      return ordered;
    case CollectionShelfSort.figureCount:
      final sectionOrder = List<ShelfUniverseSection>.from(
        groupShelfSeriesByUniverse(series),
      )..sort((a, b) {
          final cmp =
              _ipFigureCountTotal(b).compareTo(_ipFigureCountTotal(a));
          if (cmp != 0) return cmp;
          return _compareIpSectionLabels(a, b);
        });
      final byFigureCount = <ShelfSeries>[];
      for (final section in sectionOrder) {
        final copy = List<ShelfSeries>.from(section.series)
          ..sort((a, b) {
            final cmp = b.figureCount.compareTo(a.figureCount);
            if (cmp != 0) return cmp;
            return _compareShelfSeriesByNameThenId(a, b);
          });
        byFigureCount.addAll(copy);
      }
      return byFigureCount;
    case CollectionShelfSort.completion:
      final sectionOrder = List<ShelfUniverseSection>.from(
        groupShelfSeriesByUniverse(series),
      )..sort((a, b) {
          final cmp = _ipWeightedCompletion(b, states, progress: progress)
              .compareTo(_ipWeightedCompletion(a, states, progress: progress));
          if (cmp != 0) return cmp;
          return _compareIpSectionLabels(a, b);
        });
      final byCompletion = <ShelfSeries>[];
      for (final section in sectionOrder) {
        final copy = List<ShelfSeries>.from(section.series)
          ..sort((a, b) {
            final cmp = _seriesCompletionRatio(b, states, progress: progress)
                .compareTo(_seriesCompletionRatio(a, states, progress: progress));
            if (cmp != 0) return cmp;
            return _compareShelfSeriesByNameThenId(a, b);
          });
        byCompletion.addAll(copy);
      }
      return byCompletion;
  }
}
