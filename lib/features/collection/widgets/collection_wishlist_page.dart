import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_wishlist_browse.dart';
import 'package:blindbox_app/features/collection/widgets/collection_brand_filter_row.dart';
import 'package:blindbox_app/features/collection/widgets/collection_browse_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_ip_filter_row.dart';
import 'package:blindbox_app/shared/widgets/bling_heart_empty_state.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/catalog_quick_action_button.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_filter_section_label.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class CollectionWishlistPage extends StatefulWidget {
  const CollectionWishlistPage({
    super.key,
    required this.snapshot,
    required this.searchQuery,
    required this.onRemoveSeries,
    required this.onRemoveFigure,
    required this.onOpenSeries,
    required this.onOpenFigure,
  });

  final CollectionSnapshot snapshot;
  final String searchQuery;
  final ValueChanged<WishlistedCatalogSeries> onRemoveSeries;
  final ValueChanged<WishlistedFigureRow> onRemoveFigure;
  final ValueChanged<WishlistedCatalogSeries> onOpenSeries;
  final ValueChanged<WishlistedFigureRow> onOpenFigure;

  /// Test-only: wishlist page rebuilds.
  @visibleForTesting
  static int debugBuildCount = 0;

  /// Test-only: wishlist filter pipeline executions.
  @visibleForTesting
  static int debugFilterCount = 0;

  @override
  State<CollectionWishlistPage> createState() => _CollectionWishlistPageState();
}

class _CollectionWishlistPageState extends State<CollectionWishlistPage> {
  String _brandFilterId = collectionAnyBrandFilterId;
  String _ipFilterId = collectionAnyIpFilterId;
  CollectionWishlistSort _sort = CollectionWishlistSort.recentlyAdded;
  bool _seriesExpanded = true;
  bool _figuresExpanded = true;

  @override
  Widget build(BuildContext context) {
    assert(() {
      CollectionWishlistPage.debugBuildCount++;
      return true;
    }());
    assert(() {
      CollectionWishlistPage.debugFilterCount++;
      return true;
    }());
    final allFigures = wishlistedFigureRows(widget.snapshot);
    final brandOptions = buildWishlistBrandFilterOptions(
      widget.snapshot.seriesWishlist,
      allFigures,
    );
    final ipOptions = buildWishlistIpFilterOptions(
      widget.snapshot.seriesWishlist,
      allFigures,
    );
    final activeBrand = _resolveSelection(
      _brandFilterId,
      brandOptions.map((o) => o.id),
      collectionAnyBrandFilterId,
    );
    final activeIp = _resolveSelection(
      _ipFilterId,
      ipOptions.map((o) => o.id),
      collectionAnyIpFilterId,
    );
    if (activeBrand != _brandFilterId || activeIp != _ipFilterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _brandFilterId = activeBrand;
          _ipFilterId = activeIp;
        });
      });
    }

    final series = sortWishlistSeries(
      filterWishlistSeries(
        series: widget.snapshot.seriesWishlist,
        query: widget.searchQuery,
        brandFilterId: activeBrand,
        ipFilterId: activeIp,
      ),
      _sort,
    );
    final figures = sortWishlistFigures(
      filterWishlistFigures(
        figures: allFigures,
        query: widget.searchQuery,
        brandFilterId: activeBrand,
        ipFilterId: activeIp,
      ),
      _sort,
    );
    final hasAnySource =
        widget.snapshot.seriesWishlist.isNotEmpty || allFigures.isNotEmpty;
    final hasActiveNarrowing =
        widget.searchQuery.trim().isNotEmpty ||
        activeBrand != collectionAnyBrandFilterId ||
        activeIp != collectionAnyIpFilterId;
    final noVisibleResults =
        hasAnySource && hasActiveNarrowing && series.isEmpty && figures.isEmpty;
    final showSeriesSection = series.isNotEmpty;
    final showFiguresSection = figures.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: FeedRhythm.tabScrollTailPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TaxonomyFilterSectionLabel(text: 'Brand'),
          const SizedBox(height: FeedRhythm.collectionFilterSectionLabelToRail),
          CollectionBrandFilterRow(
            options: [
              for (final option in brandOptions)
                (id: option.id, label: option.label),
            ],
            selectedBrandId: activeBrand,
            onBrandSelected: (id) => setState(() => _brandFilterId = id),
          ),
          const SizedBox(
            height: FeedRhythm.collectionBrandToIpFilterSectionGap,
          ),
          const TaxonomyFilterSectionLabel(text: 'IP'),
          const SizedBox(height: FeedRhythm.collectionFilterSectionLabelToRail),
          CollectionIpFilterRow(
            options: [
              for (final option in ipOptions)
                (id: option.id, label: option.label),
            ],
            selectedIpId: activeIp,
            onIpSelected: (id) => setState(() => _ipFilterId = id),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
            child: Align(
              alignment: Alignment.centerRight,
              child: _WishlistSortMenu(
                selected: _sort,
                onSelected: (sort) => setState(() => _sort = sort),
              ),
            ),
          ),
          if (!hasAnySource)
            const _WishlistWholeEmptyState()
          else if (noVisibleResults)
            const _WishlistNoResultsState(
              title: 'No Wishlist results found.',
              body: 'Adjust search or filters to see saved items.',
            )
          else ...[
            if (showSeriesSection) ...[
              _WishlistSectionHeader(
                title: 'Series',
                count: series.length,
                expanded: _seriesExpanded,
                onToggle: () =>
                    setState(() => _seriesExpanded = !_seriesExpanded),
              ),
              if (_seriesExpanded)
                _SeriesGrid(
                  series: series,
                  onRemove: widget.onRemoveSeries,
                  onOpen: widget.onOpenSeries,
                ),
            ],
            if (showSeriesSection && showFiguresSection)
              const SizedBox(height: 10),
            if (showFiguresSection) ...[
              _WishlistSectionHeader(
                title: 'Figures',
                count: figures.length,
                expanded: _figuresExpanded,
                onToggle: () =>
                    setState(() => _figuresExpanded = !_figuresExpanded),
              ),
              if (_figuresExpanded)
                _FigureGrid(
                  figures: figures,
                  onRemove: widget.onRemoveFigure,
                  onOpen: widget.onOpenFigure,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

String _resolveSelection(
  String selected,
  Iterable<String> optionIds,
  String fallback,
) {
  return optionIds.contains(selected) ? selected : fallback;
}

class _WishlistSectionHeader extends StatelessWidget {
  const _WishlistSectionHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$title ($count)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  color: scheme.onSurface.withValues(alpha: 0.92),
                ),
              ),
            ),
            Icon(
              expanded
                  ? Symbols.expand_less_rounded
                  : Symbols.expand_more_rounded,
              size: AppIconSizes.expand,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesGrid extends StatelessWidget {
  const _SeriesGrid({
    required this.series,
    required this.onRemove,
    required this.onOpen,
  });

  final List<WishlistedCatalogSeries> series;
  final ValueChanged<WishlistedCatalogSeries> onRemove;
  final ValueChanged<WishlistedCatalogSeries> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('wishlist_series_grid'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: CollectionCardTokens.maxPackedMinRailHeight,
      ),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final item = series[index];
        return _WishlistCard(
          title: item.name,
          subtitle: item.ipName,
          meta: item.brand,
          imageKey: item.imageKey,
          imageMode: CatalogImageDisplayMode.seriesCoverThumb,
          removeSemanticsLabel: 'Remove Series from Wishlist',
          removeTargetKey: ValueKey(
            'wishlist_remove_series_${item.catalogSeriesId}',
          ),
          onRemove: () => onRemove(item),
          onTap: () => onOpen(item),
        );
      },
    );
  }
}

class _FigureGrid extends StatelessWidget {
  const _FigureGrid({
    required this.figures,
    required this.onRemove,
    required this.onOpen,
  });

  final List<WishlistedFigureRow> figures;
  final ValueChanged<WishlistedFigureRow> onRemove;
  final ValueChanged<WishlistedFigureRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final cardHeight = CollectionCardTokens.wishlistFigureHeight(
      MediaQuery.textScalerOf(context),
    );
    return GridView.builder(
      key: const Key('wishlist_figures_grid'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: cardHeight,
      ),
      itemCount: figures.length,
      itemBuilder: (context, index) {
        final row = figures[index];
        return _WishlistCard(
          title: row.figure.name,
          subtitle: row.series.name,
          meta: row.series.brand.trim().isNotEmpty
              ? row.series.brand
              : shelfSeriesIpLabel(row.series),
          imageKey: row.figure.imageKey ?? row.figure.id,
          imageMode: CatalogImageDisplayMode.figureWishlistCard,
          height: cardHeight,
          reserveTwoTitleLines: true,
          removeSemanticsLabel: 'Remove Figure from Wishlist',
          removeTargetKey: ValueKey('wishlist_remove_figure_${row.figure.id}'),
          onRemove: () => onRemove(row),
          onTap: () => onOpen(row),
        );
      },
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.imageKey,
    required this.imageMode,
    required this.removeSemanticsLabel,
    required this.removeTargetKey,
    required this.onRemove,
    this.height = CollectionCardTokens.minRailHeight,
    this.reserveTwoTitleLines = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String imageKey;
  final CatalogImageDisplayMode imageMode;
  final String removeSemanticsLabel;
  final Key removeTargetKey;
  final VoidCallback onRemove;
  final VoidCallback? onTap;
  final double height;
  final bool reserveTwoTitleLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: CollectionBrowseCard(
        onTap: onTap,
        title: title,
        subtitle: subtitle,
        subtitleMaxLines: 2,
        reserveTwoTitleLines: reserveTwoTitleLines,
        height: height,
        padding: CollectionCardTokens.padding,
        imageToTitleGap: CollectionCardTokens.imageToTitleGap,
        titleToMetaGap: CollectionCardTokens.titleToMetaGap,
        metaToFooterGap: CollectionCardTokens.metaToProgressGap,
        // Keep series subtitle under the figure title (not floated to footer).
        expandBeforeMeta: false,
        titleStyle: CollectibleTypography.catalogSeriesRowTitle(
          textTheme,
          scheme,
        ),
        subtitleStyle: CollectibleTypography.seriesIpLine(textTheme, scheme),
        image: CatalogImageFromKey(
          imageKey: imageKey,
          name: title,
          seedKey: imageKey,
          displayMode: imageMode,
          borderRadius: BorderRadius.zero,
        ),
        footer: Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CollectibleTypography.catalogSeriesRowMeta(
            textTheme,
            scheme,
          ).copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.62)),
        ),
        borderColor: scheme.outlineVariant.withValues(
          alpha: isDark ? 0.32 : 0.38,
        ),
        overlayBuilder: (context) => Positioned(
          top: 8,
          right: 8,
          child: _WishlistRemoveAction(
            targetKey: removeTargetKey,
            semanticsLabel: removeSemanticsLabel,
            onRemove: onRemove,
          ),
        ),
      ),
    );
  }
}

class _WishlistRemoveAction extends StatelessWidget {
  const _WishlistRemoveAction({
    required this.targetKey,
    required this.semanticsLabel,
    required this.onRemove,
  });

  final Key targetKey;
  final String semanticsLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CatalogQuickActionButton(
      key: targetKey,
      tooltip: semanticsLabel,
      semanticsLabel: semanticsLabel,
      icon: Symbols.close_rounded,
      active: true,
      onPressed: onRemove,
    );
  }
}

class _WishlistNoResultsState extends StatelessWidget {
  const _WishlistNoResultsState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.emptyStateTitle(textTheme, scheme),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.emptyStateBody(textTheme, scheme),
          ),
        ],
      ),
    );
  }
}

/// Calm empty composition — bling heart illustration + title + body.
class _WishlistEmptyState extends StatelessWidget {
  const _WishlistEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: BlingHeartEmptyState(
              heartKey: Key('wishlist_empty_heart_icon'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.emptyStateTitle(textTheme, scheme),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.emptyStateBody(textTheme, scheme),
          ),
        ],
      ),
    );
  }
}

class _WishlistWholeEmptyState extends StatelessWidget {
  const _WishlistWholeEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('wishlist_whole_empty_state'),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: _WishlistEmptyState(
          title: 'Your wishlist is empty.',
          body: 'Save catalog series to plan what to collect next.',
        ),
      ),
    );
  }
}

class _WishlistSortMenu extends StatelessWidget {
  const _WishlistSortMenu({required this.selected, required this.onSelected});

  final CollectionWishlistSort selected;
  final ValueChanged<CollectionWishlistSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<CollectionWishlistSort>(
      key: const Key('collection_wishlist_sort_menu'),
      initialValue: selected,
      tooltip: 'Sort wishlist',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final sort in CollectionWishlistSort.values)
          PopupMenuItem<CollectionWishlistSort>(
            value: sort,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: sort == selected
                      ? Icon(
                          Symbols.check_rounded,
                          size: 20,
                          color: scheme.primary,
                        )
                      : null,
                ),
                Expanded(child: Text(sort.menuLabel)),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.sort_rounded,
            size: AppIconSizes.metadata,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
          ),
          const SizedBox(width: 6),
          Text(
            selected.menuLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            Symbols.expand_more_rounded,
            size: AppIconSizes.metadata,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ],
      ),
    );
  }
}
