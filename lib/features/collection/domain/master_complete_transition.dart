import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:flutter/foundation.dart';

/// Series rows that newly reached Master Complete between two shelf snapshots.
///
/// Cold-start restores and unchanged rows are ignored — only live false→true
/// transitions on existing shelf series count.
List<ShelfSeries> newlyMasterCompleteSeries(
  CollectionSnapshot previous,
  CollectionSnapshot next,
) {
  final result = <ShelfSeries>[];
  for (final series in next.shelfSeries) {
    final existedBefore =
        previous.shelfSeries.any((s) => s.id == series.id);
    if (!existedBefore) continue;

    final wasMaster = resolveSeriesCompletion(
      series,
      previous.figureStates,
    ).isMasterComplete;
    final nowMaster = resolveSeriesCompletion(
      series,
      next.figureStates,
    ).isMasterComplete;
    if (!wasMaster && nowMaster) {
      result.add(series);
    }
  }
  return result;
}

@visibleForTesting
bool seriesNewlyMasterComplete({
  required ShelfSeries series,
  required CollectionSnapshot previous,
  required CollectionSnapshot next,
}) {
  return newlyMasterCompleteSeries(previous, next).any((s) => s.id == series.id);
}
