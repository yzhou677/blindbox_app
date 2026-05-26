import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_series_search_row_card.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/feed_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home entry: catalog search → series preview → figure gallery.
class CatalogBrowseScreen extends ConsumerStatefulWidget {
  const CatalogBrowseScreen({super.key});

  @override
  ConsumerState<CatalogBrowseScreen> createState() => _CatalogBrowseScreenState();
}

class _CatalogBrowseScreenState extends ConsumerState<CatalogBrowseScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _search.text.trim();
  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

  Future<void> _openSeriesPreview(
    BuildContext context,
    CatalogSeedBundle bundle,
    String seriesId,
  ) async {
    final template = await catalogTemplateFromSeedSeries(
      bundle,
      seriesId,
      resolveFigureImages: false,
    );
    if (!context.mounted || template == null) return;

    final notifier = ref.read(collectionNotifierProvider.notifier);
    final snap = ref.read(collectionNotifierProvider);
    final onShelf = snap.hasTemplateOnShelf(seriesId);

    await showCollectibleBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      heightFraction: FeedRhythm.sheetPreviewOpenScreenFraction,
      builder: (ctx, scroll) => CatalogSeriesPreviewSheet(
        series: template,
        onAdd: onShelf
            ? () {}
            : () => commitCatalogSeriesToShelf(notifier, template),
        showAddButton: !onShelf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bundleAsync = ref.watch(catalogBundleProvider);
    final snap = ref.watch(collectionNotifierProvider);

    return bundleAsync.when(
      loading: () => FeedSearchScreen(
        title: 'Search catalog',
        hintText: 'Search catalog — figures, series, IPs, aliases…',
        emptyPrompt: 'Search by series, figure, or IP.',
        controller: _search,
        hasSearchText: _hasSearchText,
        onChanged: (_) => setState(() {}),
        onClear: _search.clear,
        results: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => FeedSearchScreen(
        title: 'Search catalog',
        hintText: 'Search catalog — figures, series, IPs, aliases…',
        emptyPrompt: 'Search by series, figure, or IP.',
        controller: _search,
        hasSearchText: _hasSearchText,
        onChanged: (_) => setState(() {}),
        onClear: _search.clear,
        results: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Couldn’t load the catalog. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
      data: (bundle) {
        final matches = _hasSearchText
            ? buildCatalogSeriesSearchRows(
                bundle: bundle,
                query: _trimmedQuery,
              )
            : const <CatalogSeriesSearchRow>[];

        return FeedSearchScreen(
          title: 'Search catalog',
          hintText: 'Search catalog — figures, series, IPs, aliases…',
          emptyPrompt: 'Search by series, figure, or IP.',
          controller: _search,
          hasSearchText: _hasSearchText,
          onChanged: (_) => setState(() {}),
          onClear: _search.clear,
          results: matches.isEmpty
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
                    final onShelf = snap.hasTemplateOnShelf(row.seriesId);
                    return CatalogSeriesSearchRowCard(
                      key: ValueKey<String>(
                        'catalog-browse:${row.seriesId}',
                      ),
                      row: row,
                      trailingLabel: onShelf ? 'View' : 'Browse',
                      onOpenPreview: () => _openSeriesPreview(
                        ctx,
                        bundle,
                        row.seriesId,
                      ),
                      onTrailingAction: () => _openSeriesPreview(
                        ctx,
                        bundle,
                        row.seriesId,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
