import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_lookup.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filter_matching.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Local Filters-sheet density — tighter than generic [FeedRhythm] sheet gaps.
abstract final class _FiltersSheetDensity {
  static const double titleToBody = 14;
  static const double sectionGap = 28;
  static const double labelToControl = 12;
  static const double settingsRowHeight = 56;
  static const double afterDivider = 16;
}

/// Result of applying the combined Filters sheet (filters + sort stay separate).
@immutable
class CollectionShelfFiltersSheetResult {
  const CollectionShelfFiltersSheetResult({
    required this.filters,
    required this.sort,
  });

  final CollectionShelfFilters filters;
  final CollectionShelfSort sort;

  @override
  bool operator ==(Object other) {
    return other is CollectionShelfFiltersSheetResult &&
        other.filters == filters &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(filters, sort);
}

/// Collapsed Brand summary for the Filters sheet.
String collectionShelfBrandFilterSummary({
  required Set<String> selectedIds,
  required List<CollectionBrandFilterOption> options,
}) {
  if (selectedIds.isEmpty) return CollectionVocabulary.filterAllBrandsSummary;
  if (selectedIds.length == 1) {
    final id = selectedIds.first;
    for (final o in options) {
      if (o.id == id) return o.label;
    }
    return CollectionVocabulary.filterSelectedCountSummary(1);
  }
  return CollectionVocabulary.filterSelectedCountSummary(selectedIds.length);
}

/// Collapsed IP summary for the Filters sheet.
String collectionShelfIpFilterSummary({
  required Set<String> selectedIds,
  required List<CollectionIpFilterOption> options,
}) {
  if (selectedIds.isEmpty) return CollectionVocabulary.filterAllIpsSummary;
  if (selectedIds.length == 1) {
    final id = selectedIds.first;
    for (final o in options) {
      if (o.id == id) return o.label;
    }
    return CollectionVocabulary.filterSelectedCountSummary(1);
  }
  return CollectionVocabulary.filterSelectedCountSummary(selectedIds.length);
}

/// Opens the Collection filters sheet with draft Filters and draft Sort.
///
/// Returns [CollectionShelfFiltersSheetResult] when the user taps Show, or
/// `null` if dismissed without applying. Preview counts use
/// [previewCollectionShelfFilterResults] — Sort does not affect the count.
Future<CollectionShelfFiltersSheetResult?> showCollectionShelfFiltersSheet({
  required BuildContext context,
  required CollectionShelfFilters initial,
  CollectionShelfSort initialSort = CollectionShelfSort.recentlyAdded,
  String searchQuery = '',
  List<ShelfSeries>? shelfSeries,
  Map<String, TrackedFigure>? figureStates,
  CatalogBundleLookup? catalogLookup,
}) {
  return showCollectionModalBottomSheet<CollectionShelfFiltersSheetResult>(
    context: context,
    heightFraction: FeedRhythm.sheetOpenScreenFraction,
    builder: (context, scrollController) {
      return _CollectionShelfFiltersSheet(
        initial: initial,
        initialSort: initialSort,
        scrollController: scrollController,
        searchQuery: searchQuery,
        shelfSeriesOverride: shelfSeries,
        figureStatesOverride: figureStates,
        catalogLookupOverride: catalogLookup,
      );
    },
  );
}

class _CollectionShelfFiltersSheet extends ConsumerStatefulWidget {
  const _CollectionShelfFiltersSheet({
    required this.initial,
    required this.initialSort,
    required this.scrollController,
    required this.searchQuery,
    this.shelfSeriesOverride,
    this.figureStatesOverride,
    this.catalogLookupOverride,
  });

  final CollectionShelfFilters initial;
  final CollectionShelfSort initialSort;
  final ScrollController scrollController;
  final String searchQuery;
  final List<ShelfSeries>? shelfSeriesOverride;
  final Map<String, TrackedFigure>? figureStatesOverride;
  final CatalogBundleLookup? catalogLookupOverride;

  @override
  ConsumerState<_CollectionShelfFiltersSheet> createState() =>
      _CollectionShelfFiltersSheetState();
}

class _CollectionShelfFiltersSheetState
    extends ConsumerState<_CollectionShelfFiltersSheet> {
  late CollectionShelfFilters _draft;
  late CollectionShelfSort _draftSort;
  String _brandQuery = '';
  String _ipQuery = '';
  var _brandExpanded = false;
  var _ipExpanded = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _draftSort = widget.initialSort;
  }

  void _apply() => Navigator.of(
    context,
  ).pop(CollectionShelfFiltersSheetResult(filters: _draft, sort: _draftSort));

  /// Clears draft Filters only — draft Sort is preserved.
  void _clearAll() => setState(() {
    _draft = CollectionShelfFilters.empty;
    _brandQuery = '';
    _ipQuery = '';
  });

  void _setDraft(CollectionShelfFilters next, List<ShelfSeries> shelfSeries) {
    setState(() {
      _draft = pruneCollectionShelfIpIdsToBrandScope(next, shelfSeries);
    });
  }

  void _setDraftSort(CollectionShelfSort sort) {
    if (sort == _draftSort) return;
    setState(() => _draftSort = sort);
  }

  List<CollectionBrandFilterOption> _allBrandOptions(List<ShelfSeries> shelf) {
    return buildCollectionShelfBrandFilterOptions(
      shelf,
    ).where((o) => o.id != collectionAnyBrandFilterId).toList();
  }

  List<CollectionBrandFilterOption> _brandOptions(List<ShelfSeries> shelf) {
    final all = _allBrandOptions(shelf);
    final q = _brandQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final o in all)
        if (o.label.toLowerCase().contains(q) || o.id.contains(q)) o,
    ];
  }

  List<CollectionIpFilterOption> _allIpOptions(List<ShelfSeries> shelf) {
    final brandScoped = _draft.brandIds.isEmpty
        ? shelf
        : [
            for (final s in shelf)
              if (_draft.brandIds.contains(
                collectionBrandFilterKeyForSeries(s),
              ))
                s,
          ];
    return buildCollectionShelfIpFilterOptions(
      brandScoped,
    ).where((o) => o.id != collectionAnyIpFilterId).toList();
  }

  List<CollectionIpFilterOption> _ipOptions(List<ShelfSeries> shelf) {
    final all = _allIpOptions(shelf);
    final q = _ipQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final o in all)
        if (o.label.toLowerCase().contains(q) || o.id.contains(q)) o,
    ];
  }

  Future<void> _openSortChooser() async {
    final selected = await showCollectionModalBottomSheet<CollectionShelfSort>(
      context: context,
      wrapContentHeight: true,
      builder: (context, scrollController) {
        return _SortChooserSheet(
          selected: _draftSort,
          scrollController: scrollController,
        );
      },
    );
    if (!mounted || selected == null) return;
    _setDraftSort(selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final snap = ref.watch(collectionNotifierProvider);
    final shelfSeries = widget.shelfSeriesOverride ?? snap.shelfSeries;
    final figureStates = widget.figureStatesOverride ?? snap.figureStates;
    final catalogLookup =
        widget.catalogLookupOverride ?? ref.watch(catalogBundleLookupProvider);
    final catalogBundle = resolveCatalogBundleForSearch(
      providerBundle: ref.watch(catalogBundleProvider).valueOrNull,
    );
    final catalogSearch = ref.watch(catalogSearchServiceProvider);

    final preview = previewCollectionShelfFilterResults(
      shelfSeries: shelfSeries,
      figureStates: figureStates,
      filters: _draft,
      searchQuery: widget.searchQuery,
      catalog: catalogLookup,
      catalogBundle: catalogBundle,
      catalogSearch: catalogSearch,
    );

    final orderedPreviewIds = preview.waitingOnCatalog
        ? const <String>[]
        : sortShelfSeriesForDisplay(
            preview.series,
            _draftSort,
            figureStates,
            catalog: catalogBundle,
          ).map((s) => s.id).toList(growable: false);

    final allBrands = _allBrandOptions(shelfSeries);
    final brandOptions = _brandOptions(shelfSeries);
    final allIps = _allIpOptions(shelfSeries);
    final ipOptions = _ipOptions(shelfSeries);
    final brandSummary = collectionShelfBrandFilterSummary(
      selectedIds: _draft.brandIds,
      options: allBrands,
    );
    final ipSummary = collectionShelfIpFilterSummary(
      selectedIds: _draft.ipIds,
      options: allIps,
    );

    return CollectibleSheetInsets(
      extraBottom: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CollectibleSheetScrollView(
              controller: widget.scrollController,
              header: const CollectibleSheetChrome(
                editorialTitle: CollectionVocabulary.filters,
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: _FiltersSheetDensity.titleToBody,
                      bottom: FeedRhythm.sheetBodyBottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KeyedSubtree(
                          key: ValueKey(
                            'filters_sheet_preview_ids_${orderedPreviewIds.join('|')}',
                          ),
                          child: const SizedBox.shrink(),
                        ),
                        _FiltersSettingsRow(
                          key: const Key('filters_sheet_sort_row'),
                          title: CollectionVocabulary.filterSectionSortBy,
                          value: _draftSort.menuLabel,
                          valueKey: const Key('filters_sheet_sort_row_value'),
                          trailing: Icon(
                            Symbols.chevron_right_rounded,
                            size: AppIconSizes.metadata,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          semanticsLabel:
                              '${CollectionVocabulary.filterSectionSortBy}, ${_draftSort.semanticLabel}',
                          scheme: scheme,
                          textTheme: textTheme,
                          onTap: _openSortChooser,
                        ),
                        _filtersHairline(scheme),
                        SizedBox(height: _FiltersSheetDensity.afterDivider),
                        _sectionLabel(
                          CollectionVocabulary.filterSectionProgress,
                          textTheme,
                          scheme,
                        ),
                        const SizedBox(
                          height: _FiltersSheetDensity.labelToControl,
                        ),
                        Wrap(
                          spacing: FeedRhythm.sheetControlGap,
                          runSpacing: FeedRhythm.sheetControlGap,
                          children: [
                            for (final option
                                in CollectionShelfProgressFilter.values)
                              TaxonomyFilterPillChip(
                                key: Key(
                                  'filters_sheet_progress_${option.name}',
                                ),
                                label: switch (option) {
                                  CollectionShelfProgressFilter.inProgress =>
                                    CollectionVocabulary
                                        .progressInProgressFilter,
                                  CollectionShelfProgressFilter.completed =>
                                    CollectionVocabulary
                                        .progressCompletedFilter,
                                  CollectionShelfProgressFilter
                                      .masterComplete =>
                                    CollectionVocabulary
                                        .progressMasterCompleteFilter,
                                },
                                selected: _draft.progress == option,
                                compact: true,
                                emphasized: true,
                                horizontalPadding: 8,
                                onTap: () => _setDraft(
                                  _draft.toggleProgress(option),
                                  shelfSeries,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: _FiltersSheetDensity.sectionGap),
                        _FiltersSettingsRow(
                          key: const Key('filters_sheet_brand_section'),
                          title: CollectionVocabulary.filterBrand,
                          value: brandSummary,
                          trailing: Icon(
                            _brandExpanded
                                ? Symbols.expand_less_rounded
                                : Symbols.expand_more_rounded,
                            size: AppIconSizes.expand,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          semanticsLabel:
                              '${CollectionVocabulary.filterBrand}, $brandSummary',
                          semanticsExpanded: _brandExpanded,
                          scheme: scheme,
                          textTheme: textTheme,
                          onTap: () =>
                              setState(() => _brandExpanded = !_brandExpanded),
                        ),
                        if (_brandExpanded) ...[
                          const SizedBox(
                            height: _FiltersSheetDensity.labelToControl,
                          ),
                          if (allBrands.length > 1) ...[
                            _FacetSearchField(
                              hint: CollectionVocabulary.filterSearchBrandsHint,
                              onChanged: (v) => setState(() => _brandQuery = v),
                            ),
                            const SizedBox(
                              height: _FiltersSheetDensity.labelToControl,
                            ),
                          ],
                          Wrap(
                            spacing: FeedRhythm.sheetControlGap,
                            runSpacing: FeedRhythm.sheetControlGap,
                            children: [
                              for (final option in brandOptions)
                                TaxonomyFilterPillChip(
                                  key: Key('filters_sheet_brand_${option.id}'),
                                  label: option.label,
                                  selected: _draft.brandIds.contains(option.id),
                                  compact: true,
                                  emphasized: true,
                                  onTap: () => _setDraft(
                                    _draft.toggleBrandId(option.id),
                                    shelfSeries,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        _filtersHairline(scheme),
                        _FiltersSettingsRow(
                          key: const Key('filters_sheet_ip_section'),
                          title: CollectionVocabulary.filterIp,
                          value: ipSummary,
                          trailing: Icon(
                            _ipExpanded
                                ? Symbols.expand_less_rounded
                                : Symbols.expand_more_rounded,
                            size: AppIconSizes.expand,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          semanticsLabel:
                              '${CollectionVocabulary.filterIp}, $ipSummary',
                          semanticsExpanded: _ipExpanded,
                          scheme: scheme,
                          textTheme: textTheme,
                          onTap: () =>
                              setState(() => _ipExpanded = !_ipExpanded),
                        ),
                        if (_ipExpanded) ...[
                          const SizedBox(
                            height: _FiltersSheetDensity.labelToControl,
                          ),
                          if (allIps.length > 1) ...[
                            _FacetSearchField(
                              hint: CollectionVocabulary.filterSearchIpsHint,
                              onChanged: (v) => setState(() => _ipQuery = v),
                            ),
                            const SizedBox(
                              height: _FiltersSheetDensity.labelToControl,
                            ),
                          ],
                          Wrap(
                            spacing: FeedRhythm.sheetControlGap,
                            runSpacing: FeedRhythm.sheetControlGap,
                            children: [
                              for (final option in ipOptions)
                                TaxonomyFilterPillChip(
                                  key: Key('filters_sheet_ip_${option.id}'),
                                  label: option.label,
                                  selected: _draft.ipIds.contains(option.id),
                                  compact: true,
                                  emphasized: true,
                                  onTap: () => _setDraft(
                                    _draft.toggleIpId(option.id),
                                    shelfSeries,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: _FiltersSheetDensity.sectionGap),
                        _sectionLabel(
                          CollectionVocabulary
                              .filterSectionCollectionAttributes,
                          textTheme,
                          scheme,
                        ),
                        const SizedBox(
                          height: _FiltersSheetDensity.labelToControl,
                        ),
                        Wrap(
                          spacing: FeedRhythm.sheetControlGap,
                          runSpacing: FeedRhythm.sheetControlGap,
                          children: [
                            _attrChip(
                              key: const Key('filters_sheet_has_duplicates'),
                              label: CollectionVocabulary.hasDuplicatesFilter,
                              selected: _draft.hasDuplicates,
                              onTap: () => _setDraft(
                                _draft.copyWith(
                                  hasDuplicates: !_draft.hasDuplicates,
                                ),
                                shelfSeries,
                              ),
                            ),
                            _attrChip(
                              key: const Key('filters_sheet_has_wishlist'),
                              label:
                                  CollectionVocabulary.hasWishlistItemsFilter,
                              selected: _draft.hasWishlistItems,
                              onTap: () => _setDraft(
                                _draft.copyWith(
                                  hasWishlistItems: !_draft.hasWishlistItems,
                                ),
                                shelfSeries,
                              ),
                            ),
                            _attrChip(
                              key: const Key('filters_sheet_secret_owned'),
                              label: CollectionVocabulary.secretOwnedFilter,
                              selected: _draft.secretOwned,
                              onTap: () => _setDraft(
                                _draft.copyWith(
                                  secretOwned: !_draft.secretOwned,
                                ),
                                shelfSeries,
                              ),
                            ),
                            _attrChip(
                              key: const Key('filters_sheet_secret_missing'),
                              label: CollectionVocabulary.secretMissingFilter,
                              selected: _draft.secretMissing,
                              onTap: () => _setDraft(
                                _draft.copyWith(
                                  secretMissing: !_draft.secretMissing,
                                ),
                                shelfSeries,
                              ),
                            ),
                            _attrChip(
                              key: const Key('filters_sheet_custom_series'),
                              label: CollectionVocabulary.customSeriesFilter,
                              selected: _draft.customSeries,
                              onTap: () => _setDraft(
                                _draft.copyWith(
                                  customSeries: !_draft.customSeries,
                                ),
                                shelfSeries,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: FeedRhythm.sheetFooterVertical,
            ),
            child: Row(
              children: [
                TextButton(
                  key: const Key('filters_sheet_clear_all'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    disabledForegroundColor: scheme.onSurface.withValues(
                      alpha: 0.42,
                    ),
                  ),
                  onPressed: _draft.hasActive ? _clearAll : null,
                  child: const Text(CollectionVocabulary.clearAllFilters),
                ),
                const SizedBox(width: FeedRhythm.sheetControlGap),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      key: const Key('filters_sheet_show_results'),
                      onPressed: _apply,
                      child: preview.waitingOnCatalog
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  CollectionVocabulary.showFilterSeriesCount(
                                    preview.count,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                SizedBox(
                                  key: const Key(
                                    'filters_sheet_results_loading',
                                  ),
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              CollectionVocabulary.showFilterSeriesCount(
                                preview.count,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, TextTheme textTheme, ColorScheme scheme) {
    return Text(
      text,
      style: CollectibleTypography.shelfFigureSheetSectionLabel(
        textTheme,
        scheme,
      ),
    );
  }

  Widget _filtersHairline(ColorScheme scheme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: scheme.outlineVariant.withValues(alpha: 0.28),
    );
  }

  Widget _attrChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return TaxonomyFilterPillChip(
      key: key,
      label: label,
      selected: selected,
      compact: true,
      emphasized: true,
      onTap: onTap,
    );
  }
}

/// Unified 56dp settings row for Sort / Brand / IP.
class _FiltersSettingsRow extends StatelessWidget {
  const _FiltersSettingsRow({
    super.key,
    required this.title,
    required this.value,
    required this.trailing,
    required this.semanticsLabel,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
    this.valueKey,
    this.semanticsExpanded,
  });

  final String title;
  final String value;
  final Key? valueKey;
  final Widget trailing;
  final String semanticsLabel;
  final bool? semanticsExpanded;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: semanticsExpanded,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _FiltersSheetDensity.settingsRowHeight,
            child: Row(
              children: [
                Text(
                  title,
                  style: CollectibleTypography.shelfFigureSheetSectionLabel(
                    textTheme,
                    scheme,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    value,
                    key: valueKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nested Sort chooser — selecting an option pops immediately (draft only).
///
/// Sized to content (see [showCollectionModalBottomSheet.wrapContentHeight]);
/// shrink-wrapped list scrolls only when large text / short screens overflow.
class _SortChooserSheet extends StatelessWidget {
  const _SortChooserSheet({
    required this.selected,
    required this.scrollController,
  });

  final CollectionShelfSort selected;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CollectibleSheetInsets(
      key: const Key('filters_sheet_sort_chooser'),
      extraBottom: 0,
      child: CustomScrollView(
        controller: scrollController,
        shrinkWrap: true,
        // Avoid AlwaysScrollable — it expands the viewport to the max height.
        physics: const ClampingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: CollectibleSheetChrome(
              editorialTitle: CollectionVocabulary.filterSectionSortBy,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: FeedRhythm.sheetTitleToBody,
                bottom: FeedRhythm.sheetBodyBottomInset,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final sort in CollectionShelfSort.values)
                    _SortChooserOptionRow(
                      sort: sort,
                      selected: sort == selected,
                      scheme: scheme,
                      textTheme: textTheme,
                      onTap: () => Navigator.of(context).pop(sort),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChooserOptionRow extends StatelessWidget {
  const _SortChooserOptionRow({
    required this.sort,
    required this.selected,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final CollectionShelfSort sort;
  final bool selected;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  static const double _rowMinHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: sort.semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('filters_sheet_sort_${sort.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sort.menuLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Symbols.radio_button_checked_rounded
                        : Symbols.radio_button_unchecked_rounded,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FacetSearchField extends StatelessWidget {
  const _FacetSearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: Icon(
          Symbols.search_rounded,
          size: AppIconSizes.metadata,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
      ),
    );
  }
}
