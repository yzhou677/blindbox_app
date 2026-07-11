import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Horizontal showcase of top owned series — compact [CollectionSeriesCard] rail.
///
/// Resolves reveal-time series names against the live shelf for media / progress.
/// Presentation only; does not change how top series are calculated.
class CollectorTypeTopSeriesRail extends ConsumerWidget {
  const CollectorTypeTopSeriesRail({
    super.key,
    required this.seriesNames,
  });

  final List<String> seriesNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seriesNames.isEmpty) return const SizedBox.shrink();

    final snap = ref.watch(collectionNotifierProvider);
    final byName = <String, ShelfSeries>{
      for (final s in snap.shelfSeries) s.name: s,
    };
    final rows = <ShelfSeries>[
      for (final name in seriesNames) ?byName[name],
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final progress = ShelfBrowseProgressLookup(snap.figureStates);
    const density = CollectionSeriesCardDensity.compact;

    return SizedBox(
      height: CollectionSeriesCard.railExtentFor(density),
      child: ListView.separated(
        key: const Key('collector_type_top_series_rail'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
        ),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: FeedRhythm.horizontalRailCardGap),
        itemBuilder: (context, index) {
          final row = rows[index];
          return CollectionSeriesCard(
            key: ValueKey('top_series_${row.id}'),
            series: row,
            progress: progress.forSeries(row),
            figureStates: snap.figureStates,
            density: density,
            onTap: () => _openFiguresSheet(context, row.id),
          );
        },
      ),
    );
  }

  void _openFiguresSheet(BuildContext context, String seriesId) {
    showCollectibleBottomSheet<void>(
      context: context,
      heightFraction: FeedRhythm.sheetFiguresOpenScreenFraction,
      builder: (_, scroll) => SeriesFiguresSheet(seriesId: seriesId),
    );
  }
}
