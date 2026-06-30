import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle_loader.dart';
import 'package:blindbox_app/features/catalog/catalog_latest_series.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/core/search/search_placeholders.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_provider.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_series_search_row_card.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_shelf_cta_trailing.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/add_series_catalog_copy.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/widgets/collectible_browse_card.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:blindbox_app/shared/widgets/series_hero_meta_block.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Add from catalog suggestions (searchable) or create a custom series.
class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.onCreateCustom});

  final VoidCallback onCreateCustom;

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  final _search = TextEditingController();
  CatalogSeedBundle? _catalogBundle;
  bool _catalogLoadFailed = false;
  Future<List<CatalogSeries>>? _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadCatalog();
  }

  void _loadCatalog() {
    final cached = CatalogBundleCache.current;
    if (cached != null) {
      _applyCatalogBundle(cached);
    }
    loadCatalogBundle()
        .then((b) {
          if (!mounted) return;
          _applyCatalogBundle(b);
        })
        .catchError((_) {
          if (mounted && _catalogBundle == null) {
            setState(() {
              _catalogLoadFailed = true;
              _catalogBundle = null;
              _recommendationsFuture = null;
            });
          }
        });
  }

  void _applyCatalogBundle(CatalogSeedBundle b) {
    final snap = ref.read(collectionNotifierProvider);
    setState(() {
      _catalogBundle = b;
      _catalogLoadFailed = false;
      _recommendationsFuture = _loadRecommendationTemplates(b, snap);
    });
  }

  Future<List<CatalogSeries>> _loadRecommendationTemplates(
    CatalogSeedBundle bundle,
    CollectionSnapshot snap,
  ) async {
    final picks = pickLatestSeriesRecommendations(bundle, snap);
    final templates = await Future.wait(
      picks.map(
        (seedSeries) => catalogTemplateFromSeedSeries(
          bundle,
          seedSeries.id,
          resolveFigureImages: false,
        ),
      ),
    );
    return [
      for (final t in templates)
        ?t,
    ];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _search.text.trim();

  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

  void _recordSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    ref.read(catalogSearchHistoryProvider.notifier).add(q);
  }

  String _seriesCoverImageKey(CatalogSeedBundle bundle, String seriesId) {
    for (final s in bundle.series) {
      if (s.id == seriesId) return s.imageKey.trim();
    }
    return '';
  }

  CollectionSeriesShelfCtaPresentation _previewShelfCta(
    CollectionSnapshot snap,
    CatalogSeries series,
  ) {
    return CollectionSeriesShelfCtaPresentation.resolve(
      snapshot: snap,
      layout: CollectionSeriesShelfCtaLayout.previewSticky,
      catalogTemplateId: series.templateId,
      seriesName: series.name,
      brandName: series.brand,
      taxonomyBrandId: series.taxonomyBrandId,
      taxonomyIpId: series.taxonomyIpId,
    );
  }

  void _openCatalogSeriesPreview(
    BuildContext context, {
    required CatalogSeries series,
    required CollectionSnapshot snap,
    required VoidCallback onAdd,
  }) {
    final shelfCta = _previewShelfCta(snap, series);
    // Same branch navigator as the parent sheet — root overlay stacks a second
    // modal and leaves the parent drag handle visually pinned on dismiss.
    showCollectionModalBottomSheet<void>(
      context: context,
      heightFraction: FeedRhythm.sheetPreviewOpenScreenFraction,
      builder: (_, scroll) => CatalogSeriesPreviewSheet(
        series: series,
        shelfCta: shelfCta,
        onAdd: onAdd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snap = ref.watch(collectionNotifierProvider);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final catalogActive = _trimmedQuery.isNotEmpty;
    final sheetScroll = CollectibleSheetScope.scrollControllerOf(context);

    return CollectibleSheetInsets(
      extraBottom: AppSpacing.md,
      child: CollectibleSheetScrollView(
        controller: sheetScroll,
        header: CollectibleSheetChrome(
          editorialTitle: 'Add a series',
          editorialSubtitle: AddSeriesCatalogCopy.sheetSubtitle,
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              controller: _search,
              padding: EdgeInsets.zero,
              hintText: SearchPlaceholders.localCatalog,
              onChanged: (_) => setState(() {}),
              onSubmitted: () => _recordSearch(_trimmedQuery),
              suffixIcon: !_hasSearchText
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(
                        Icons.close_rounded,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
            if (catalogActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  AddSeriesCatalogCopy.catalogListHeading(searchActive: true),
                  style: CollectibleTypography.catalogSeriesRowMeta(
                    textTheme,
                    scheme,
                  ),
                ),
              )
            else if (!_catalogLoadFailed && _catalogBundle != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Latest releases',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
          ],
            ),
          ),
          if (catalogActive)
            _buildCatalogSearchSliver(
              context,
              scheme,
              textTheme,
              snap,
              notifier,
            )
          else
            _buildRecommendationsSliver(
              context,
              scheme,
              textTheme,
              notifier,
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.tonal(
              onPressed: widget.onCreateCustom,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.draw_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Create my own series'),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSliver(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    CollectionNotifier notifier,
  ) {
    if (_catalogLoadFailed) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Couldn’t load the catalog. Check your connection and try again.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ),
      );
    }
    if (_catalogBundle == null || _recommendationsFuture == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    return FutureBuilder<List<CatalogSeries>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Couldn’t load recommendations.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        }
        final recs = snapshot.data ?? const <CatalogSeries>[];
        if (recs.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'No catalog series to show yet.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          );
        }
        final snap = ref.watch(collectionNotifierProvider);
        return SliverList.separated(
          itemCount: recs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final s = recs[i];
            final coverKey = _seriesCoverImageKey(
              _catalogBundle!,
              s.templateId,
            );
            final shelfCta = CollectionSeriesShelfCtaPresentation.resolve(
              snapshot: snap,
              layout: CollectionSeriesShelfCtaLayout.compactTrailing,
              catalogTemplateId: s.templateId,
              seriesName: s.name,
              brandName: s.brand,
              taxonomyBrandId: s.taxonomyBrandId,
              taxonomyIpId: s.taxonomyIpId,
            );
            return _SuggestionCard(
              key: ValueKey<String>('add-series-rec:${s.templateId}'),
              series: s,
              coverImageKey: coverKey,
              shelfCta: shelfCta,
              onOpenPreview: () {
                _openCatalogSeriesPreview(
                  ctx,
                  series: s,
                  snap: snap,
                  onAdd: () => commitCatalogSeriesToShelf(notifier, s),
                );
              },
              onAdd: () => commitCatalogSeriesToShelf(notifier, s),
            );
          },
        );
      },
    );
  }

  Widget _buildCatalogSearchSliver(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    CollectionSnapshot snap,
    CollectionNotifier notifier,
  ) {
    if (_catalogLoadFailed) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Couldn’t load the catalog. Check your connection and try again.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ),
      );
    }
    final bundle = _catalogBundle;
    if (bundle == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final matches = buildCatalogSeriesSearchRows(
      bundle: bundle,
      query: _trimmedQuery,
    );
    if (matches.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            AddSeriesCatalogCopy.noSearchMatches,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: matches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final row = matches[i];
        final shelfCta = CollectionSeriesShelfCtaPresentation.resolve(
          snapshot: snap,
          layout: CollectionSeriesShelfCtaLayout.compactTrailing,
          catalogTemplateId: row.seriesId,
          seriesName: row.seriesTitle,
          brandName: row.brand,
          taxonomyBrandId: row.taxonomyBrandId,
          taxonomyIpId: row.taxonomyIpId,
        );
        return CatalogSeriesSearchRowCard(
          key: ValueKey<String>('add-series-search:${row.seriesId}'),
          row: row,
          shelfCta: shelfCta,
          onOpenPreview: () async {
            _recordSearch(_trimmedQuery);
            final template = await catalogTemplateFromSeedSeries(
              bundle,
              row.seriesId,
              resolveFigureImages: false,
            );
            if (!ctx.mounted || template == null) return;
            _openCatalogSeriesPreview(
              ctx,
              series: template,
              snap: snap,
              onAdd: () => commitCatalogSeriesToShelf(notifier, template),
            );
          },
          onShelfCtaPressed: () async {
            _recordSearch(_trimmedQuery);
            if (!shelfCta.isAddable) return;
            final template = await catalogTemplateFromSeedSeries(
              bundle,
              row.seriesId,
              resolveFigureImages: false,
            );
            if (template != null) {
              commitCatalogSeriesToShelf(notifier, template);
            }
          },
        );
      },
    );
  }

}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.series,
    required this.coverImageKey,
    required this.shelfCta,
    required this.onOpenPreview,
    required this.onAdd,
  });

  final CatalogSeries series;
  final String coverImageKey;
  final CollectionSeriesShelfCtaPresentation shelfCta;
  final VoidCallback onOpenPreview;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CollectibleBrowseCard(
      onTap: onOpenPreview,
      borderColor: series.shelfAccent.withValues(alpha: 0.42),
      fillGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.surfaceContainerLow,
          Color.lerp(scheme.surfaceContainerLow, series.shelfAccent, 0.12)!,
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CatalogImageSlot(
            displayMode: CatalogImageDisplayMode.seriesCoverThumb,
            borderRadius: AppRadii.insetRadius,
            child: coverImageKey.isNotEmpty
                      ? CatalogImageFromKey(
                          key: catalogImageWidgetKey(
                            displayMode:
                                CatalogImageDisplayMode.seriesCoverThumb,
                            imageKey: coverImageKey,
                            identity: series.templateId,
                          ),
                          imageKey: coverImageKey,
                          name: series.name,
                          seedKey: series.templateId,
                          compact: true,
                          displayMode: CatalogImageDisplayMode.seriesCoverThumb,
                          borderRadius: BorderRadius.zero,
                        )
                      : ColoredBox(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          child: Icon(
                            Icons.photo_outlined,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.name,
                        style: CollectibleTypography.catalogSeriesRowTitle(
                          textTheme,
                          scheme,
                        ),
                      ),
                      SeriesHeroMetaBlock(
                        brand: series.brand,
                        ipLine: series.ipName,
                        trailingMeta: series.figureCount == 1
                            ? '1 figure'
                            : '${series.figureCount} figures',
                        density: SeriesHeroMetaDensity.compact,
                      ),
                    ],
                  ),
                ),
          CollectionSeriesShelfCtaTrailing(
            presentation: shelfCta,
            onPressed: shelfCta.isAddable ? onAdd : null,
          ),
        ],
      ),
    );
  }
}
