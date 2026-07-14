import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';

const int kShelfShareFeaturedSeriesLimit = 6;

List<ShelfSeries> selectShelfShareFeaturedSeries(
  CollectionSnapshot snapshot, {
  int limit = kShelfShareFeaturedSeriesLimit,
}) {
  if (limit <= 0 || snapshot.shelfSeries.isEmpty) return const [];

  final indexed =
      <({ShelfSeries series, int index, SeriesCompletionResolution r})>[
        for (var i = 0; i < snapshot.shelfSeries.length; i++)
          (
            series: snapshot.shelfSeries[i],
            index: i,
            r: resolveSeriesCompletion(
              snapshot.shelfSeries[i],
              snapshot.figureStates,
            ),
          ),
      ];

  indexed.sort((a, b) {
    final tier = _featuredTier(b.r).compareTo(_featuredTier(a.r));
    if (tier != 0) return tier;

    final progress = b.r.progressRatio.compareTo(a.r.progressRatio);
    if (progress != 0) return progress;

    final encounter = a.index.compareTo(b.index);
    if (encounter != 0) return encounter;

    final name = a.series.name.toLowerCase().compareTo(
      b.series.name.toLowerCase(),
    );
    if (name != 0) return name;

    return a.series.id.compareTo(b.series.id);
  });

  return [for (final row in indexed.take(limit)) row.series];
}

int _featuredTier(SeriesCompletionResolution r) {
  if (r.isMasterComplete) return 3;
  if (r.isCompleted) return 2;
  return 1;
}
