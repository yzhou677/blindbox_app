import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_lookup.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart'
    as catalog_figure;
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:flutter/foundation.dart';

/// Pure Collection shelf filter matching (shared by browse pipeline + sheet counts).
///
/// See [CollectionShelfFilters] for combination semantics. Do not reimplement
/// these predicates in widgets.

/// Result of applying draft/committed filters (and optional search) for counts.
@immutable
class CollectionShelfFilterPreview {
  const CollectionShelfFilterPreview({
    required this.series,
    required this.waitingOnCatalog,
  });

  /// Matching shelf series (search already applied when requested).
  final List<ShelfSeries> series;

  /// True when Secret filters need catalog metadata that is not ready yet.
  /// UI should show a loading affordance instead of a false zero.
  final bool waitingOnCatalog;

  int get count => series.length;
}

/// Applies [filters] to [series] with AND across sections.
List<ShelfSeries> applyCollectionShelfFilters(
  List<ShelfSeries> series,
  Map<String, TrackedFigure> states,
  CollectionShelfFilters filters, {
  ShelfBrowseProgressLookup? progress,
  CatalogBundleLookup? catalog,
}) {
  final normalized = normalizeCollectionShelfFilters(filters);
  if (!normalized.hasActive) return series;
  return [
    for (final row in series)
      if (shelfSeriesMatchesFilters(
        row,
        states,
        normalized,
        progress: progress,
        catalog: catalog,
      ))
        row,
  ];
}

/// Shared Collection browse visibility: filters → search (same as the shelf).
///
/// Used by [CollectionScreen] and the Filters sheet preview count so they cannot
/// disagree.
CollectionShelfFilterPreview previewCollectionShelfFilterResults({
  required List<ShelfSeries> shelfSeries,
  required Map<String, TrackedFigure> figureStates,
  required CollectionShelfFilters filters,
  String searchQuery = '',
  ShelfBrowseProgressLookup? progress,
  CatalogBundleLookup? catalog,
  CatalogSeedBundle? catalogBundle,
  CatalogSearchService? catalogSearch,
}) {
  final normalized = normalizeCollectionShelfFilters(filters);
  final needsCatalog = normalized.secretOwned || normalized.secretMissing;
  final waitingOnCatalog =
      needsCatalog &&
      catalog == null &&
      shelfSeries.any(_seriesMayNeedCatalogSecrets);

  if (waitingOnCatalog) {
    return const CollectionShelfFilterPreview(
      series: [],
      waitingOnCatalog: true,
    );
  }

  final filtered = applyCollectionShelfFilters(
    shelfSeries,
    figureStates,
    normalized,
    progress: progress,
    catalog: catalog,
  );
  final searched = filterShelfSeriesBySearch(
    filtered,
    searchQuery,
    catalog: catalogBundle,
    catalogSearch: catalogSearch,
    figureSeriesIdByFigureId: catalog?.figureSeriesIdIndex,
  );
  return CollectionShelfFilterPreview(
    series: searched,
    waitingOnCatalog: false,
  );
}

bool shelfSeriesMatchesFilters(
  ShelfSeries series,
  Map<String, TrackedFigure> states,
  CollectionShelfFilters filters, {
  ShelfBrowseProgressLookup? progress,
  CatalogBundleLookup? catalog,
}) {
  if (filters.brandIds.isNotEmpty) {
    final key = collectionBrandFilterKeyForSeries(series);
    if (key.isEmpty || !filters.brandIds.contains(key)) return false;
  }
  if (filters.ipIds.isNotEmpty) {
    final key = collectionIpFilterKeyForSeries(series);
    if (key.isEmpty || !filters.ipIds.contains(key)) return false;
  }

  final progressFilter = filters.progress;
  if (progressFilter != null) {
    if (!shelfSeriesMatchesProgressFilter(
      series,
      states,
      progressFilter,
      catalog: catalog,
    )) {
      return false;
    }
  }

  if (filters.hasDuplicates) {
    final counts =
        progress?.forSeries(series) ?? progressForSeries(series, states);
    if (!counts.hasDuplicates) return false;
  }
  if (filters.hasWishlistItems) {
    final counts =
        progress?.forSeries(series) ?? progressForSeries(series, states);
    if (counts.wishlist <= 0) return false;
  }
  if (filters.secretOwned || filters.secretMissing) {
    final resolution = resolveSeriesCompletionForFilters(
      series,
      states,
      catalog: catalog,
    );
    if (filters.secretOwned) {
      if (resolution.secretSlotCount <= 0 || resolution.secretOwnedCount <= 0) {
        return false;
      }
    }
    if (filters.secretMissing) {
      if (resolution.secretSlotCount <= 0 ||
          resolution.secretOwnedCount >= resolution.secretSlotCount) {
        return false;
      }
    }
  }
  if (filters.customSeries && !series.isCustomLocal) return false;

  return true;
}

/// Progress filter matching.
///
/// UI selection remains single-choice, but matching sets nest:
/// [CollectionShelfProgressFilter.completed] includes Master Complete series;
/// [CollectionShelfProgressFilter.masterComplete] is Master-only.
bool shelfSeriesMatchesProgressFilter(
  ShelfSeries series,
  Map<String, TrackedFigure> states,
  CollectionShelfProgressFilter filter, {
  CatalogBundleLookup? catalog,
}) {
  final resolution = resolveSeriesCompletionForFilters(
    series,
    states,
    catalog: catalog,
  );
  switch (filter) {
    case CollectionShelfProgressFilter.inProgress:
      // Align with [partitionShelfSeries]: any incomplete shelf row, including
      // zero-owned. Do not require [isStartedSeries] (Collector Type concept).
      return !resolution.isCompleted;
    case CollectionShelfProgressFilter.completed:
      return resolution.isCompleted;
    case CollectionShelfProgressFilter.masterComplete:
      return resolution.isMasterComplete;
  }
}

/// Completion resolution for filters — Secret slots come from catalog metadata
/// when the shelf row still has a false/missing [ShelfFigure.isSecret] flag.
SeriesCompletionResolution resolveSeriesCompletionForFilters(
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  CatalogBundleLookup? catalog,
}) {
  if (catalog == null) {
    return resolveSeriesCompletion(series, states);
  }

  var regularSlots = 0;
  var secretSlots = 0;
  var regularOwned = 0;
  var secretOwned = 0;

  for (final fig in series.figures) {
    final owned = states[fig.id]?.owned == true;
    final secret = shelfFigureIsSecretForFilter(fig, catalog);
    if (secret) {
      secretSlots++;
      if (owned) secretOwned++;
    } else {
      regularSlots++;
      if (owned) regularOwned++;
    }
  }

  return SeriesCompletionResolution(
    regularSlotCount: regularSlots,
    secretSlotCount: secretSlots,
    regularOwnedCount: regularOwned,
    secretOwnedCount: secretOwned,
  );
}

/// Whether [fig] is a Secret for filter matching.
///
/// Prefer the shelf flag when already true; otherwise consult catalog by
/// [ShelfFigure.catalogFigureTemplateId]. Never infers from figure names.
bool shelfFigureIsSecretForFilter(
  ShelfFigure fig,
  CatalogBundleLookup? catalog,
) {
  if (fig.isSecret) return true;
  final templateId = fig.catalogFigureTemplateId?.trim();
  if (templateId == null || templateId.isEmpty || catalog == null) {
    return false;
  }
  final catalog_figure.CatalogFigure? catalogFigure = catalog.figureById(
    templateId,
  );
  return catalogFigure?.isSecret ?? false;
}

bool _seriesMayNeedCatalogSecrets(ShelfSeries series) {
  if (series.isCustomLocal) return false;
  // Only wait when a catalog-linked figure is not already flagged Secret —
  // shelf `isSecret: true` is authoritative and does not need the bundle.
  for (final fig in series.figures) {
    if (fig.isSecret) continue;
    final templateId = fig.catalogFigureTemplateId?.trim();
    if (templateId != null && templateId.isNotEmpty) return true;
  }
  return false;
}

/// Prunes brand/IP keys that no longer exist on the shelf (session hygiene)
/// and normalizes single-choice groups.
CollectionShelfFilters pruneCollectionShelfFiltersToShelf(
  CollectionShelfFilters filters,
  List<ShelfSeries> shelfSeries,
) {
  final normalized = normalizeCollectionShelfFilters(filters);
  if (normalized.brandIds.isEmpty && normalized.ipIds.isEmpty) {
    return normalized;
  }
  final brands = <String>{
    for (final s in shelfSeries) collectionBrandFilterKeyForSeries(s),
  }..removeWhere((k) => k.isEmpty);
  final ips = <String>{
    for (final s in shelfSeries) collectionIpFilterKeyForSeries(s),
  }..removeWhere((k) => k.isEmpty);
  final nextBrands = normalized.brandIds.intersection(brands);
  final nextIps = normalized.ipIds.intersection(ips);
  final pruned = normalized.copyWith(brandIds: nextBrands, ipIds: nextIps);
  if (pruned == normalized) return normalized;
  return pruneCollectionShelfIpIdsToBrandScope(pruned, shelfSeries);
}

/// Drops selected IP keys that are not present under the current brand scope.
CollectionShelfFilters pruneCollectionShelfIpIdsToBrandScope(
  CollectionShelfFilters filters,
  List<ShelfSeries> shelfSeries,
) {
  final normalized = normalizeCollectionShelfFilters(filters);
  if (normalized.ipIds.isEmpty) return normalized;
  final brandScoped = normalized.brandIds.isEmpty
      ? shelfSeries
      : [
          for (final s in shelfSeries)
            if (normalized.brandIds.contains(
              collectionBrandFilterKeyForSeries(s),
            ))
              s,
        ];
  final allowed = <String>{
    for (final s in brandScoped) collectionIpFilterKeyForSeries(s),
  }..removeWhere((k) => k.isEmpty);
  final nextIps = normalized.ipIds.intersection(allowed);
  if (setEquals(nextIps, normalized.ipIds)) return normalized;
  return normalized.copyWith(ipIds: nextIps);
}
