import 'package:blindbox_app/core/search/search_matcher.dart';
import 'package:blindbox_app/core/search/search_normalizer.dart';
import 'package:blindbox_app/core/search/search_tokenizer.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:flutter/foundation.dart';

/// Display-only sort modes for the Collection shelf browse pipeline.
enum CollectionShelfSort {
  recentlyAdded,
  recentlyReleased,
  alphabetical,
  figureCount,
  completion,
}

extension CollectionShelfSortLabels on CollectionShelfSort {
  String get menuLabel => switch (this) {
    CollectionShelfSort.recentlyAdded => 'Recently Added',
    CollectionShelfSort.recentlyReleased => 'Recently Released',
    CollectionShelfSort.alphabetical => 'Alphabetical (A–Z)',
    CollectionShelfSort.figureCount => 'Figure Count',
    CollectionShelfSort.completion => 'Completion',
  };

  /// Spoken / accessibility label — keeps the visible menu short.
  String get semanticLabel => switch (this) {
    CollectionShelfSort.recentlyReleased =>
      'Recently Released, by U.S. release date',
    _ => menuLabel,
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
/// Prefer [figureSeriesIdByFigureId] (e.g. from [CatalogBundleLookup]) to avoid
/// rebuilding the figure→series map on each call.
List<ShelfSeries> filterShelfSeriesBySearch(
  List<ShelfSeries> series,
  String query, {
  CatalogSeedBundle? catalog,
  CatalogSearchService? catalogSearch,
  Map<String, String>? figureSeriesIdByFigureId,
}) {
  final tokens = SearchTokenizer.tokenize(query);
  if (tokens.isEmpty) return series;

  final catalogSeriesIds = catalogSearch != null
      ? catalogSearch.matchingSeriesIds(query)
      : catalog != null
      ? CatalogSearchService(catalog).matchingSeriesIds(query)
      : const <String>{};

  final figureSeriesLookup =
      figureSeriesIdByFigureId ??
      (catalog != null && catalogSeriesIds.isNotEmpty
          ? _catalogFigureIdToSeriesId(catalog)
          : null);

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

/// Keeps series that appear in [matchedIds], preserving [ordered] traversal.
///
/// When [matchedIds] is `null`, every row matches (empty committed query).
List<ShelfSeries> intersectShelfSeriesBySearchMatchIds(
  List<ShelfSeries> ordered,
  Set<String>? matchedIds,
) {
  if (matchedIds == null) return ordered;
  if (matchedIds.isEmpty) return const [];
  return [
    for (final row in ordered)
      if (matchedIds.contains(row.id)) row,
  ];
}

/// Revision-aware cache of text-search matches for Collection shelf browse.
///
/// Brand/IP chip taps must intersect this set instead of re-running
/// [filterShelfSeriesBySearch] / [CatalogSearchService.matchingSeriesIds].
final class ShelfBrowseSearchMatchCache {
  List<ShelfSeries>? _shelf;
  String _query = '';
  CatalogSearchService? _catalogSearch;
  CatalogSeedBundle? _catalog;
  Map<String, String>? _figureSeriesIdByFigureId;

  /// `null` means empty query (all series match).
  Set<String>? _matchedIds;

  /// Test-only: full text-search pipeline executions (cache misses).
  @visibleForTesting
  static int debugSearchExecutionCount = 0;

  /// Test-only: cache hits that skipped text search.
  @visibleForTesting
  static int debugCacheHitCount = 0;

  /// Returns matched shelf series ids for [query].
  ///
  /// `null` = empty query (treat as match-all). Non-null empty set = no matches.
  Set<String>? matchedIds({
    required List<ShelfSeries> shelf,
    required String query,
    CatalogSeedBundle? catalog,
    CatalogSearchService? catalogSearch,
    Map<String, String>? figureSeriesIdByFigureId,
  }) {
    if (identical(_shelf, shelf) &&
        _query == query &&
        identical(_catalogSearch, catalogSearch) &&
        identical(_catalog, catalog) &&
        identical(_figureSeriesIdByFigureId, figureSeriesIdByFigureId)) {
      assert(() {
        ShelfBrowseSearchMatchCache.debugCacheHitCount++;
        return true;
      }());
      return _matchedIds;
    }

    _shelf = shelf;
    _query = query;
    _catalogSearch = catalogSearch;
    _catalog = catalog;
    _figureSeriesIdByFigureId = figureSeriesIdByFigureId;

    final tokens = SearchTokenizer.tokenize(query);
    if (tokens.isEmpty) {
      _matchedIds = null;
      return null;
    }

    assert(() {
      ShelfBrowseSearchMatchCache.debugSearchExecutionCount++;
      return true;
    }());
    final matched = filterShelfSeriesBySearch(
      shelf,
      query,
      catalog: catalog,
      catalogSearch: catalogSearch,
      figureSeriesIdByFigureId: figureSeriesIdByFigureId,
    );
    _matchedIds = {for (final row in matched) row.id};
    return _matchedIds;
  }

  void invalidate() {
    _shelf = null;
    _query = '';
    _catalogSearch = null;
    _catalog = null;
    _figureSeriesIdByFigureId = null;
    _matchedIds = null;
  }
}

Map<String, String> _catalogFigureIdToSeriesId(CatalogSeedBundle catalog) {
  return {for (final fig in catalog.figures) fig.id: fig.seriesId};
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

/// When [hasDuplicatesOnly] is true, keep series with at least one extra copy.
///
/// A series matches when [seriesDuplicateCount] > 0. Combines with brand/IP/
/// search by applying after those facets (AND semantics).
List<ShelfSeries> shelfSeriesVisibleForDuplicatesFilter(
  List<ShelfSeries> series,
  Map<String, TrackedFigure> states, {
  required bool hasDuplicatesOnly,
  ShelfBrowseProgressLookup? progress,
}) {
  if (!hasDuplicatesOnly) return series;
  return [
    for (final row in series)
      if ((progress?.forSeries(row) ?? progressForSeries(row, states))
          .hasDuplicates)
        row,
  ];
}

/// Single-pass split into in-progress and completed buckets.
(List<ShelfSeries> inProgress, List<ShelfSeries> completed)
partitionShelfSeries(
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

/// Completion-sort tier — higher sorts first.
///
/// Matches product achievement order: Master Complete → Complete →
/// Near Complete ([SeriesCompletionResolution.isNearComplete]) → In Progress.
/// Threshold matches [atmosphereForSeries] / shelf “almost complete” voice.
int _completionSortTier(ShelfSeries series, Map<String, TrackedFigure> states) {
  final resolution = resolveSeriesCompletion(series, states);
  if (resolution.isMasterComplete) return 3;
  if (resolution.isCompleted) return 2;
  if (resolution.isNearComplete) return 1;
  return 0;
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
/// [CollectionShelfSort.recentlyReleased] orders by shelf or catalog release
/// date (newest first). Series without a parseable release date sort last.
///
/// See `docs/COLLECTION_ARCHITECTURE_NOTES.md` → Collection sorting.
List<ShelfSeries> sortShelfSeriesForDisplay(
  List<ShelfSeries> series,
  CollectionShelfSort sort,
  Map<String, TrackedFigure> states, {
  ShelfBrowseProgressLookup? progress,
  CatalogSeedBundle? catalog,
  Map<String, catalog.CatalogSeries>? catalogSeriesById,
}) {
  switch (sort) {
    case CollectionShelfSort.recentlyAdded:
      return series;
    case CollectionShelfSort.recentlyReleased:
      final lookup =
          catalogSeriesById ??
          (catalog == null ? null : {for (final s in catalog.series) s.id: s});
      return List<ShelfSeries>.from(series)..sort((a, b) {
        final da = catalogReleaseDateForShelfSeries(
          a,
          catalogSeriesById: lookup,
        );
        final db = catalogReleaseDateForShelfSeries(
          b,
          catalogSeriesById: lookup,
        );
        if (da != null && db != null) {
          final byDate = db.compareTo(da);
          if (byDate != 0) return byDate;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        return _compareShelfSeriesByNameThenId(a, b);
      });
    case CollectionShelfSort.alphabetical:
      return List<ShelfSeries>.from(series)
        ..sort(_compareShelfSeriesByNameThenId);
    case CollectionShelfSort.figureCount:
      return List<ShelfSeries>.from(series)..sort((a, b) {
        final cmp = b.figureCount.compareTo(a.figureCount);
        if (cmp != 0) return cmp;
        return _compareShelfSeriesByNameThenId(a, b);
      });
    case CollectionShelfSort.completion:
      return List<ShelfSeries>.from(series)..sort((a, b) {
        final tierCmp = _completionSortTier(
          b,
          states,
        ).compareTo(_completionSortTier(a, states));
        if (tierCmp != 0) return tierCmp;
        final ratioCmp = _seriesCompletionRatio(
          b,
          states,
          progress: progress,
        ).compareTo(_seriesCompletionRatio(a, states, progress: progress));
        if (ratioCmp != 0) return ratioCmp;
        return _compareShelfSeriesByNameThenId(a, b);
      });
  }
}

/// Release date for a shelf series: user-authored [ShelfSeries.releaseDate]
/// first, else official catalog **U.S.** date when joinable.
DateTime? catalogReleaseDateForShelfSeries(
  ShelfSeries series, {
  Map<String, catalog.CatalogSeries>? catalogSeriesById,
}) {
  final local = parseCatalogReleaseDate(series.releaseDate);
  if (local != null) return local;
  if (catalogSeriesById == null || catalogSeriesById.isEmpty) return null;
  for (final candidate in shelfCatalogSeriesIdCandidates(series)) {
    final row = catalogSeriesById[candidate];
    final parsed = parseCatalogReleaseDate(row?.releaseDate);
    if (parsed != null) return parsed;
  }
  return null;
}

/// Parses catalog/shelf `releaseDate` (`YYYY-MM-DD` or ISO datetime) as a
/// date-only day. Returns null for missing or malformed values.
DateTime? parseCatalogReleaseDate(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Encodes a calendar day as `YYYY-MM-DD` for shelf/catalog release fields.
String formatIsoDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
