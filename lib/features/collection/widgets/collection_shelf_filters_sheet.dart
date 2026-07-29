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

/// Opens the Collection filters sheet with draft state.
///
/// Returns the applied [CollectionShelfFilters], or `null` if dismissed without
/// applying. Preview counts use [previewCollectionShelfFilterResults] — the same
/// shared path as the Collection shelf.
///
/// When [shelfSeries] / [figureStates] are omitted, the sheet watches
/// [collectionNotifierProvider] so counts stay aligned with live shelf data.
Future<CollectionShelfFilters?> showCollectionShelfFiltersSheet({
  required BuildContext context,
  required CollectionShelfFilters initial,
  String searchQuery = '',
  List<ShelfSeries>? shelfSeries,
  Map<String, TrackedFigure>? figureStates,
  CatalogBundleLookup? catalogLookup,
}) {
  return showCollectionModalBottomSheet<CollectionShelfFilters>(
    context: context,
    heightFraction: FeedRhythm.sheetOpenScreenFraction,
    builder: (context, scrollController) {
      return _CollectionShelfFiltersSheet(
        initial: initial,
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
    required this.scrollController,
    required this.searchQuery,
    this.shelfSeriesOverride,
    this.figureStatesOverride,
    this.catalogLookupOverride,
  });

  final CollectionShelfFilters initial;
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
  String _brandQuery = '';
  String _ipQuery = '';

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  void _apply() => Navigator.of(context).pop(_draft);

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

  List<CollectionBrandFilterOption> _brandOptions(List<ShelfSeries> shelf) {
    final all = buildCollectionShelfBrandFilterOptions(
      shelf,
    ).where((o) => o.id != collectionAnyBrandFilterId).toList();
    final q = _brandQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final o in all)
        if (o.label.toLowerCase().contains(q) || o.id.contains(q)) o,
    ];
  }

  List<CollectionIpFilterOption> _ipOptions(List<ShelfSeries> shelf) {
    final brandScoped = _draft.brandIds.isEmpty
        ? shelf
        : [
            for (final s in shelf)
              if (_draft.brandIds.contains(
                collectionBrandFilterKeyForSeries(s),
              ))
                s,
          ];
    final all = buildCollectionShelfIpFilterOptions(
      brandScoped,
    ).where((o) => o.id != collectionAnyIpFilterId).toList();
    final q = _ipQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final o in all)
        if (o.label.toLowerCase().contains(q) || o.id.contains(q)) o,
    ];
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

    // Shared [CollectibleSheetInsets] owns horizontal + safe bottom so the
    // title, body, and sticky actions share one left edge.
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
                      top: FeedRhythm.sheetTitleToBody,
                      bottom: FeedRhythm.sheetBodyBottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionLabel(
                          CollectionVocabulary.filterSectionProgress,
                          textTheme,
                          scheme,
                        ),
                        const SizedBox(height: FeedRhythm.sheetLabelToControl),
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
                                onTap: () => _setDraft(
                                  _draft.toggleProgress(option),
                                  shelfSeries,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: FeedRhythm.sheetSectionGap),
                        _sectionLabel(
                          CollectionVocabulary
                              .filterSectionCollectionAttributes,
                          textTheme,
                          scheme,
                        ),
                        const SizedBox(height: FeedRhythm.sheetLabelToControl),
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
                        const SizedBox(height: FeedRhythm.sheetSectionGap),
                        _sectionLabel(
                          CollectionVocabulary.filterSectionMetadata,
                          textTheme,
                          scheme,
                        ),
                        const SizedBox(height: FeedRhythm.sheetLabelToControl),
                        Text(
                          CollectionVocabulary.filterBrand,
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: FeedRhythm.sheetControlGap),
                        _FacetSearchField(
                          hint: CollectionVocabulary.filterSearchBrandsHint,
                          onChanged: (v) => setState(() => _brandQuery = v),
                        ),
                        const SizedBox(height: FeedRhythm.sheetLabelToControl),
                        Wrap(
                          spacing: FeedRhythm.sheetControlGap,
                          runSpacing: FeedRhythm.sheetControlGap,
                          children: [
                            for (final option in _brandOptions(shelfSeries))
                              TaxonomyFilterPillChip(
                                key: Key('filters_sheet_brand_${option.id}'),
                                label: option.label,
                                selected: _draft.brandIds.contains(option.id),
                                compact: true,
                                onTap: () => _setDraft(
                                  _draft.toggleBrandId(option.id),
                                  shelfSeries,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: FeedRhythm.sheetSectionGap),
                        Text(
                          CollectionVocabulary.filterIp,
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: FeedRhythm.sheetControlGap),
                        _FacetSearchField(
                          hint: CollectionVocabulary.filterSearchIpsHint,
                          onChanged: (v) => setState(() => _ipQuery = v),
                        ),
                        const SizedBox(height: FeedRhythm.sheetLabelToControl),
                        Wrap(
                          spacing: FeedRhythm.sheetControlGap,
                          runSpacing: FeedRhythm.sheetControlGap,
                          children: [
                            for (final option in _ipOptions(shelfSeries))
                              TaxonomyFilterPillChip(
                                key: Key('filters_sheet_ip_${option.id}'),
                                label: option.label,
                                selected: _draft.ipIds.contains(option.id),
                                compact: true,
                                onTap: () => _setDraft(
                                  _draft.toggleIpId(option.id),
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
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: FeedRhythm.sheetFooterVertical,
            ),
            child: Row(
              children: [
                TextButton(
                  key: const Key('filters_sheet_clear_all'),
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
                                const Text(
                                  CollectionVocabulary.showFilterResults,
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
                              _draft.hasActive
                                  ? '${CollectionVocabulary.showFilterResults} (${preview.count})'
                                  : CollectionVocabulary.showFilterResults,
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
      onTap: onTap,
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
