import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';

/// Human, shelf-first language for progress — not spreadsheet rows.
abstract final class CollectionProgressVoice {
  /// Primary emotional headline for a series row (replaces raw tallies as the hero read).
  static String seriesHeadline({
    required ShelfSeries series,
    required SeriesProgressCounts progress,
    required Map<String, TrackedFigure> figureStates,
  }) {
    final resolution = resolveSeriesCompletion(series, figureStates);
    if (resolution.isCompleted) return '';

    final total = series.figureCount;
    if (total <= 0) return '';

    final owned = progress.owned;
    final missing = resolution.regularMissingCount > 0
        ? resolution.regularMissingCount
        : progress.missing;
    final wish = progress.wishlist;

    if (missing == 0 && wish > 0 && owned < total) {
      return wish == 1 ? 'One on wishlist' : 'Several on wishlist';
    }

    if (missing == 1) return 'One figure left';
    if (missing == 2) return '2 figures left';

    final ratio = resolution.progressRatio;
    if (missing > 0 && ratio >= 0.85) return 'Almost complete';

    if (wish > 0 && missing > 0) {
      return wish == 1 ? 'Still need one' : 'Still need a few';
    }

    if (missing > 0) {
      return '$missing figures still to find';
    }

    return 'Growing this series';
  }

  /// Concise factual primary stat for shelf cards (owned/total or complete mark).
  static String seriesStatPrimaryLine({
    required ShelfSeries series,
    required SeriesProgressCounts progress,
    required Map<String, TrackedFigure> figureStates,
  }) {
    final resolution = resolveSeriesCompletion(series, figureStates);
    if (resolution.isMasterComplete) return '👑 Master Complete';
    if (resolution.isCompleted) return '✓ Complete';

    final denom = resolution.progressDenominator;
    if (denom <= 0) return '';
    return '${resolution.progressNumerator} / $denom';
  }

  /// Optional factual secondary stat — chase whisper when complete, missing while in progress.
  static String seriesStatSecondaryLine({
    required ShelfSeries series,
    required SeriesProgressCounts progress,
    required Map<String, TrackedFigure> figureStates,
  }) {
    final resolution = resolveSeriesCompletion(series, figureStates);
    if (resolution.isCompleted) {
      if (resolution.isMasterComplete || resolution.secretSlotCount == 0) {
        return '';
      }
      return '☆ Chase still out there';
    }

    final missing = resolution.regularMissingCount > 0
        ? resolution.regularMissingCount
        : progress.missing;
    if (missing <= 0) return '';
    return missing == 1 ? 'Missing 1' : 'Missing $missing';
  }

  /// Softer supporting copy — light facts, calm tone.
  static String seriesSubline({
    required ShelfSeries series,
    required SeriesProgressCounts progress,
    required Map<String, TrackedFigure> figureStates,
  }) {
    final resolution = resolveSeriesCompletion(series, figureStates);
    if (resolution.isCompleted) return '';

    final owned = progress.owned;
    final wish = progress.wishlist;
    final secrets = series.figures.where((f) => f.isSecret).toList();
    final ownedSecrets = secrets
        .where((f) => figureStates[f.id]?.owned == true)
        .length;

    final parts = <String>[];
    if (owned > 0) parts.add('$owned collected');
    if (wish > 0) parts.add('$wish on wishlist');
    if (secrets.isNotEmpty && ownedSecrets < secrets.length) {
      final openChase = secrets.length - ownedSecrets;
      if (openChase > 0) parts.add('chase still hiding');
    }
    if (parts.isEmpty) return '';
    return parts.join(' · ');
  }

  /// One calm sentence for the overview card under the stats row.
  ///
  /// Delegates to [ShelfEditorialVoice] when interpretation confidence allows.
  static String shelfMoodLine(CollectionSnapshot snap) {
    return ShelfEditorialVoice.shelfMoodLine(snap);
  }

  /// @deprecated Use [legacyShelfMoodLine] from `shelf_mood_legacy.dart`.
  static String legacyShelfMoodLine(CollectionSnapshot snap) =>
      legacyShelfMoodLine(snap);
}
