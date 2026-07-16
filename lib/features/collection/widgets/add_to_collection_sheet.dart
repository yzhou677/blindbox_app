import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_search_experience.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_search_host_actions.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_availability_card.dart';
import 'package:blindbox_app/features/collection/application/add_series_catalog_providers.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_shelf_cta_trailing.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/add_series_catalog_copy.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/core/layout/feed_rhythm.dart';
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
  static const double _stickyCreateBarReserve = 72;

  bool _searchActive = false;

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
    // Same branch navigator as the parent sheet —root overlay stacks a second
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

  CatalogSearchHostActions _searchActions(
    CollectionSnapshot snap,
    CollectionNotifier notifier,
  ) {
    return CatalogSearchHostActions(
      ctaLayout: CollectionSeriesShelfCtaLayout.compactTrailing,
      onOpenPreview: (ctx, {required seriesId, searchQuery}) {
        final template = ref.read(catalogSeriesTemplateProvider(seriesId));
        if (template == null) return;
        _openCatalogSeriesPreview(
          ctx,
          series: template,
          snap: snap,
          onAdd: () => commitCatalogSeriesToShelf(notifier, template),
        );
      },
      onShelfCtaPressed: (ctx, {required seriesId, searchQuery}) {
        final template = ref.read(catalogSeriesTemplateProvider(seriesId));
        if (template == null) return;
        commitCatalogSeriesToShelf(notifier, template);
      },
      onWishlistPressed: (ctx, {required seriesId, searchQuery}) {
        final template = ref.read(catalogSeriesTemplateProvider(seriesId));
        if (template == null) return;
        notifier.toggleSeriesWishlist(template);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snap = ref.watch(collectionNotifierProvider);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final catalogAsync = ref.watch(catalogBundleProvider);
    final availability = ref.watch(catalogAvailabilityProvider);
    final retry = ref.read(catalogDownloadRetryProvider);
    final recommendations = ref.watch(addSeriesCatalogRecommendationsProvider);
    final sheetScroll = CollectibleSheetScope.scrollControllerOf(context);
    final catalogBundle = catalogAsync.valueOrNull;

    return CollectibleSheetInsets(
      extraBottom: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CollectibleSheetScrollView(
              controller: sheetScroll,
              header: CollectibleSheetChrome(
                editorialTitle: 'Add a series',
                editorialSubtitle: AddSeriesCatalogCopy.sheetSubtitle,
              ),
              slivers: [
                CatalogSearchExperience(
                  presentation: CatalogSearchPresentation.embeddedSlivers,
                  idleBody: CatalogSearchIdleBody.none,
                  hintText: AddSeriesCatalogCopy.searchOfficialCatalogHint,
                  fieldPadding: EdgeInsets.zero,
                  autofocus: false,
                  actions: _searchActions(snap, notifier),
                  onActiveQueryChanged: (active) {
                    if (_searchActive == active) return;
                    setState(() => _searchActive = active);
                  },
                ),
                if (!_searchActive &&
                    availability.isCatalogUsable &&
                    catalogBundle != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        AddSeriesCatalogCopy.browseHeading,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.12,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.88,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_searchActive)
                  _buildBrowseSliver(
                    context,
                    scheme,
                    textTheme,
                    snap,
                    notifier,
                    availability,
                    recommendations,
                    catalogBundle,
                    retry,
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: _stickyCreateBarReserve),
                ),
              ],
            ),
          ),
          Material(
            color: scheme.surface,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.28),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
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
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseSliver(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    CollectionSnapshot snap,
    CollectionNotifier notifier,
    CatalogAvailability availability,
    List<CatalogSeries> recs,
    CatalogSeedBundle? catalogBundle,
    Future<void> Function() retry,
  ) {
    if (!availability.isCatalogUsable) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CatalogAvailabilityCard(
              availability: availability,
              onRetry: availability.isOfflineFirstLaunch ? retry : null,
              compact: true,
            ),
          ),
        ),
      );
    }
    if (catalogBundle == null) {
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
    return SliverList.separated(
      itemCount: recs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final s = recs[i];
        final coverKey = _seriesCoverImageKey(catalogBundle, s.templateId);
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
          isWishlisted: snap.hasCatalogSeriesWishlisted(s.templateId),
          onOpenPreview: () {
            _openCatalogSeriesPreview(
              ctx,
              series: s,
              snap: snap,
              onAdd: () => commitCatalogSeriesToShelf(notifier, s),
            );
          },
          onAdd: () => commitCatalogSeriesToShelf(notifier, s),
          onWishlistPressed: () => notifier.toggleSeriesWishlist(s),
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
    required this.isWishlisted,
    required this.onOpenPreview,
    required this.onAdd,
    required this.onWishlistPressed,
  });

  final CatalogSeries series;
  final String coverImageKey;
  final CollectionSeriesShelfCtaPresentation shelfCta;
  final bool isWishlisted;
  final VoidCallback onOpenPreview;
  final VoidCallback onAdd;
  final VoidCallback onWishlistPressed;

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
                      displayMode: CatalogImageDisplayMode.seriesCoverThumb,
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
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
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
          if (shelfCta.isAddable) ...[
            IconButton(
              tooltip: isWishlisted
                  ? 'Remove series from wishlist'
                  : 'Add series to wishlist',
              onPressed: onWishlistPressed,
              icon: Icon(
                isWishlisted
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isWishlisted ? scheme.primary : scheme.onSurfaceVariant,
                size: 21,
              ),
            ),
            const SizedBox(width: 2),
          ],
          CollectionSeriesShelfCtaTrailing(
            presentation: shelfCta,
            onPressed: shelfCta.isAddable ? onAdd : null,
          ),
        ],
      ),
    );
  }
}
