import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:flutter/material.dart';

/// Horizontal rail of [CollectionSeriesCard] for an In Progress / Completed bucket.
class CollectionShelfSeriesRail extends StatelessWidget {
  const CollectionShelfSeriesRail({
    super.key,
    required this.series,
    required this.figureStates,
    required this.progress,
    required this.onOpen,
  });

  final List<ShelfSeries> series;
  final Map<String, TrackedFigure> figureStates;
  final ShelfBrowseProgressLookup progress;
  final void Function(ShelfSeries series) onOpen;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: FeedRhythm.collectionShelfRailHeight,
      child: ListView.separated(
        key: const Key('collection_shelf_series_rail'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
        ),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: series.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: FeedRhythm.horizontalRailCardGap),
        itemBuilder: (context, index) {
          final row = series[index];
          return CollectionSeriesCard(
            key: ValueKey(row.id),
            series: row,
            progress: progress.forSeries(row),
            figureStates: figureStates,
            onTap: () => onOpen(row),
          );
        },
      ),
    );
  }
}
