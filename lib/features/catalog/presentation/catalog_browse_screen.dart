import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_series_search_row_card.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final template = await catalogTemplateFromSeedSeries(bundle, seriesId);
    if (!context.mounted || template == null) return;

    final notifier = ref.read(collectionNotifierProvider.notifier);
    final snap = ref.read(collectionNotifierProvider);
    final onShelf = snap.hasTemplateOnShelf(seriesId);

    final h = MediaQuery.sizeOf(context).height * 0.74;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: h,
          child: CatalogSeriesPreviewSheet(
            series: template,
            onAdd: onShelf
                ? () {}
                : () async {
                    await _addCatalogSeriesToShelf(notifier, template, bundle);
                  },
            showAddButton: !onShelf,
          ),
        ),
      ),
    );
  }

  Future<void> _addCatalogSeriesToShelf(
    CollectionNotifier notifier,
    CatalogSeries template,
    CatalogSeedBundle bundle,
  ) async {
    var toAdd = template;
    final needsResolve = template.figures.any((f) {
      final u = f.imageUrl?.trim();
      return u == null || u.isEmpty;
    });
    if (needsResolve) {
      final resolved = await catalogTemplateFromSeedSeries(
        bundle,
        template.templateId,
        resolveFigureImages: true,
      );
      if (resolved != null) toAdd = resolved;
    }
    notifier.addSeriesFromTemplate(toAdd);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bundleAsync = ref.watch(catalogBundleProvider);
    final snap = ref.watch(collectionNotifierProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Search catalog'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: bundleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
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
        data: (bundle) {
          final matches = _hasSearchText
              ? buildCatalogSeriesSearchRows(
                  bundle: bundle,
                  query: _trimmedQuery,
                )
              : const <CatalogSeriesSearchRow>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: FeedRhythm.headerToSearchField,
                ),
                child: AppSearchField(
                  controller: _search,
                  autofocus: true,
                  hintText: 'Search catalog — figures, series, IPs, aliases…',
                  onChanged: (_) => setState(() {}),
                  suffixIcon: !_hasSearchText
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: Icon(
                            Icons.close_rounded,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          onPressed: _search.clear,
                        ),
                ),
              ),
              if (_hasSearchText)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Text(
                    'Matching series',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.12,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              Expanded(
                child: !_hasSearchText
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            'Search the full catalog to browse series and figures.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.82,
                              ),
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : matches.isEmpty
                    ? Center(
                        child: Text(
                          'No matches for that search.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
