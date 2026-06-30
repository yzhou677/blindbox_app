import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';

SeriesCompletionAtmosphere atmosphereForSeries(
  ShelfSeries series,
  Map<String, TrackedFigure> figureStates, {
  bool shelfHarmony = false,
  ShelfBrowseProgressLookup? progress,
}) {
  final total = series.figureCount;
  if (total <= 0) return const SeriesCompletionAtmosphere();

  final resolution = resolveSeriesCompletion(series, figureStates);
  final seriesProgress =
      progress?.forSeries(series) ?? progressForSeries(series, figureStates);
  final ratio = seriesProgress.owned / total;

  final secrets = series.figures.where((f) => f.isSecret).toList();
  final secretRatio = secrets.isEmpty ? 0.0 : secrets.length / total;
  final rareLineup =
      (secrets.isNotEmpty && secretRatio >= 0.25) ||
      (total == 1 && secrets.isNotEmpty);

  return SeriesCompletionAtmosphere(
    nearComplete: !resolution.isCompleted && ratio >= 0.85,
    missingSecret: resolution.isCompleted &&
        resolution.secretSlotCount > 0 &&
        !resolution.isMasterComplete,
    complete: resolution.isCompleted,
    masterComplete: resolution.isMasterComplete,
    rareLineup: rareLineup,
    harmony: shelfHarmony && resolution.isCompleted,
  );
}
