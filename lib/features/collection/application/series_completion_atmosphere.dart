import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_atmosphere.dart';

SeriesCompletionAtmosphere atmosphereForSeries(
  ShelfSeries series,
  Map<String, TrackedFigure> figureStates, {
  bool shelfHarmony = false,
}) {
  final total = series.figureCount;
  if (total <= 0) return const SeriesCompletionAtmosphere();

  final progress = progressForSeries(series, figureStates);
  final complete = progress.owned >= total;
  final ratio = progress.owned / total;

  final secrets = series.figures.where((f) => f.isSecret).toList();
  final ownedSecrets = secrets
      .where((f) => figureStates[f.id]?.owned == true)
      .length;

  final secretRatio = secrets.isEmpty ? 0.0 : secrets.length / total;
  final rareLineup =
      (secrets.isNotEmpty && secretRatio >= 0.25) ||
      (total == 1 && secrets.isNotEmpty);

  return SeriesCompletionAtmosphere(
    nearComplete: !complete && ratio >= 0.85,
    missingSecret: secrets.isNotEmpty && ownedSecrets == 0,
    complete: complete,
    rareLineup: rareLineup,
    harmony: shelfHarmony && complete,
  );
}
