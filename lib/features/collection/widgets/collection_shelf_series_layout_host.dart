import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_list_tile.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_rail.dart';
import 'package:flutter/material.dart';

/// Renders one filtered/sorted bucket using the active [CollectionShelfLayout].
///
/// Layouts share the same series list — no duplicated browse logic.
class CollectionShelfSeriesLayoutHost extends StatelessWidget {
  const CollectionShelfSeriesLayoutHost({
    super.key,
    required this.layout,
    required this.series,
    required this.figureStates,
    required this.progress,
    required this.onOpen,
    this.onManage,
    this.cardContent = CollectionShelfCardContentSelection.empty,
    this.catalog,
  });

  final CollectionShelfLayout layout;
  final List<ShelfSeries> series;
  final Map<String, TrackedFigure> figureStates;
  final ShelfBrowseProgressLookup progress;
  final void Function(ShelfSeries series) onOpen;
  final Future<void> Function(ShelfSeries series)? onManage;
  final CollectionShelfCardContentSelection cardContent;
  final CatalogSeedBundle? catalog;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();

    return switch (layout) {
      CollectionShelfLayout.grid => CollectionShelfSeriesRail(
        series: series,
        figureStates: figureStates,
        progress: progress,
        onOpen: onOpen,
        onManage: onManage,
        cardContent: cardContent,
        catalog: catalog,
      ),
      CollectionShelfLayout.compactGrid => _CompactGrid(
        series: series,
        figureStates: figureStates,
        progress: progress,
        onOpen: onOpen,
        onManage: onManage,
        cardContent: cardContent,
        catalog: catalog,
      ),
      CollectionShelfLayout.list => _SeriesList(
        series: series,
        figureStates: figureStates,
        progress: progress,
        onOpen: onOpen,
        onManage: onManage,
        cardContent: cardContent,
        catalog: catalog,
      ),
    };
  }
}

class _CompactGrid extends StatelessWidget {
  const _CompactGrid({
    required this.series,
    required this.figureStates,
    required this.progress,
    required this.onOpen,
    required this.onManage,
    required this.cardContent,
    required this.catalog,
  });

  final List<ShelfSeries> series;
  final Map<String, TrackedFigure> figureStates;
  final ShelfBrowseProgressLookup progress;
  final void Function(ShelfSeries series) onOpen;
  final Future<void> Function(ShelfSeries series)? onManage;
  final CollectionShelfCardContentSelection cardContent;
  final CatalogSeedBundle? catalog;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = collectionCompactGridColumnCount(
            constraints.maxWidth,
          );
          final gap = FeedRhythm.collectionSeriesRailCardGap;
          final cardWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          final scale = (cardWidth / CollectionCardTokens.compactWidth).clamp(
            0.85,
            1.15,
          );
          final textScaler = MediaQuery.textScalerOf(context);
          final metaLineCount = cardContent.ordered.length.clamp(0, 2);
          final cardHeight =
              CollectionCardTokens.compactMinRailHeightFor(
                textScaler,
                metaLineCount: metaLineCount,
              ) *
              scale;

          return Wrap(
            key: const Key('collection_shelf_compact_grid'),
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final row in series)
                SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    child: CollectionSeriesCard(
                      key: ValueKey(row.id),
                      series: row,
                      progress: progress.forSeries(row),
                      figureStates: figureStates,
                      density: CollectionSeriesCardDensity.compact,
                      cardContent: cardContent,
                      catalog: catalog,
                      onTap: () => onOpen(row),
                      onLongPress: onManage == null
                          ? null
                          : () => onManage!(row),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SeriesList extends StatelessWidget {
  const _SeriesList({
    required this.series,
    required this.figureStates,
    required this.progress,
    required this.onOpen,
    required this.onManage,
    required this.cardContent,
    required this.catalog,
  });

  final List<ShelfSeries> series;
  final Map<String, TrackedFigure> figureStates;
  final ShelfBrowseProgressLookup progress;
  final void Function(ShelfSeries series) onOpen;
  final Future<void> Function(ShelfSeries series)? onManage;
  final CollectionShelfCardContentSelection cardContent;
  final CatalogSeedBundle? catalog;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('collection_shelf_series_list'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Column(
        children: [
          for (final row in series)
            CollectionShelfSeriesListTile(
              key: ValueKey(row.id),
              series: row,
              progress: progress.forSeries(row),
              figureStates: figureStates,
              cardContent: cardContent,
              catalog: catalog,
              onTap: () => onOpen(row),
              onLongPress: onManage == null ? null : () => onManage!(row),
            ),
        ],
      ),
    );
  }
}
