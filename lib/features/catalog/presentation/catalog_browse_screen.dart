import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/search/search_placeholders.dart';
import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_availability_copy.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_availability_card.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_provider.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_section.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_series_search_row_card.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/feed_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home entry: catalog search —series preview —figure gallery.
class CatalogBrowseScreen extends ConsumerStatefulWidget {
  const CatalogBrowseScreen({super.key});

  /// Test-only rebuild counter for search typing regression.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  ConsumerState<CatalogBrowseScreen> createState() =>
      _CatalogBrowseScreenState();
}

class _CatalogBrowseScreenState extends ConsumerState<CatalogBrowseScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _search.text.trim();

  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

  /// Live catalog search — one rebuild per query change (no debounce).
  void _onSearchChanged(String _) {
    setState(() {});
  }

  void _clearSearch() {
    final hadText = _search.text.trim().isNotEmpty;
    _search.clear();
    if (hadText) setState(() {});
  }

  void _recordSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    ref.read(catalogSearchHistoryProvider.notifier).add(q);
  }

  void _applyHistoryQuery(String query) {
    _search.text = query;
    _search.selection = TextSelection.collapsed(offset: query.length);
    setState(() {});
  }

  void _applySuggestedQuery(String query) {
    _applyHistoryQuery(query);
    _recordSearch(query);
  }

  Future<void> _openSeriesPreview(
    BuildContext context,
    String seriesId,
  ) {
    final template = ref.read(catalogSeriesTemplateProvider(seriesId));
    if (template == null) return Future.value();

    final notifier = ref.read(collectionNotifierProvider.notifier);
    final snap = ref.read(collectionNotifierProvider);
    final shelfCta = CollectionSeriesShelfCtaPresentation.resolve(
      snapshot: snap,
      layout: CollectionSeriesShelfCtaLayout.previewSticky,
      catalogTemplateId: seriesId,
      seriesName: template.name,
      brandName: template.brand,
      taxonomyBrandId: template.taxonomyBrandId,
      taxonomyIpId: template.taxonomyIpId,
    );

    return showCollectibleBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      heightFraction: FeedRhythm.sheetPreviewOpenScreenFraction,
      builder: (ctx, scroll) => CatalogSeriesPreviewSheet(
        series: template,
        shelfCta: shelfCta,
        onAdd: () => commitCatalogSeriesToShelf(notifier, template),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      CatalogBrowseScreen.debugBuildCount++;
      return true;
    }());
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bundleAsync = ref.watch(catalogBundleProvider);
    final availability = ref.watch(catalogAvailabilityProvider);
    final retry = ref.read(catalogDownloadRetryProvider);
    final snap = ref.watch(collectionNotifierProvider);
    final history = ref.watch(catalogSearchHistoryProvider);

    final historyWidget = searchEmptyQuerySection(
      history: history,
      onHistoryTap: _applyHistoryQuery,
      onRemove: (q) =>
          ref.read(catalogSearchHistoryProvider.notifier).remove(q),
      onClearAll: () =>
          ref.read(catalogSearchHistoryProvider.notifier).clearAll(),
      onSuggestedTap: _applySuggestedQuery,
    );

    final Widget results;
    final Widget? historySection;
    if (!availability.isCatalogUsable) {
      final message = CatalogAvailabilityCopy.searchMessageFor(availability);
      if (_hasSearchText) {
        historySection = null;
        results = CatalogAvailabilitySearchMessage(
          message: message,
          onRetry: availability.isOfflineFirstLaunch ? retry : null,
        );
      } else {
        historySection = CatalogAvailabilityCard(
          availability: availability,
          onRetry: availability.isOfflineFirstLaunch ? retry : null,
        );
        results = const SizedBox.shrink();
      }
    } else {
      historySection = historyWidget;
      final bundle = bundleAsync.valueOrNull;
      if (bundle == null) {
        results = const Center(child: CircularProgressIndicator());
      } else if (_hasSearchText) {
        final lookup = ref.watch(catalogBundleLookupProvider);
        final matches = buildCatalogSeriesSearchRows(
          bundle: bundle,
          query: _trimmedQuery,
          lookup: lookup,
        );
        results = matches.isEmpty
            ? Center(
                child: Text(
                  'No matches for that search.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: matches.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final row = matches[i];
                  final shelfCta =
                      CollectionSeriesShelfCtaPresentation.resolve(
                    snapshot: snap,
                    layout: CollectionSeriesShelfCtaLayout.catalogBrowse,
                    catalogTemplateId: row.seriesId,
                    seriesName: row.seriesTitle,
                    brandName: row.brand,
                    taxonomyBrandId: row.taxonomyBrandId,
                    taxonomyIpId: row.taxonomyIpId,
                  );
                  return CatalogSeriesSearchRowCard(
                    key: ValueKey<String>(
                      'catalog-browse:${row.seriesId}',
                    ),
                    row: row,
                    shelfCta: shelfCta,
                    onOpenPreview: () {
                      _recordSearch(_trimmedQuery);
                      _openSeriesPreview(ctx, row.seriesId);
                    },
                    onShelfCtaPressed: () {
                      _recordSearch(_trimmedQuery);
                      _openSeriesPreview(ctx, row.seriesId);
                    },
                  );
                },
              );
      } else {
        results = const SizedBox.shrink();
      }
    }

    return FeedSearchScreen(
      title: 'Search catalog',
      hintText: SearchPlaceholders.localCatalog,
      emptyPrompt: 'Search by series, figure, or IP.',
      controller: _search,
      onChanged: _onSearchChanged,
      onSubmitted: () => _recordSearch(_trimmedQuery),
      onClear: _clearSearch,
      historySection: historySection,
      results: results,
    );
  }
}
