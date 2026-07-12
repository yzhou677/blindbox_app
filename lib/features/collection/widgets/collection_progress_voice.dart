import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
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
      return wish == 1 ? 'One on Wishlist' : 'Several on Wishlist';
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
    if (resolution.isMasterComplete) {
      return '👑 ${CollectionVocabulary.masterComplete}';
    }
    if (resolution.isCompleted) return CollectionVocabulary.seriesCompleteBadge;

    final denom = resolution.progressDenominator;
    if (denom <= 0) return '';
    return '${resolution.progressNumerator} / $denom';
  }

  /// Series figures sheet header: Regular and Secret progress as separate lines.
  ///
  /// Answers “what am I still collecting?” — never a combined “X of Y Figures”
  /// that mixes Regular + Secret inventory.
  static String? seriesFiguresSheetProgressMeta(
    SeriesCompletionResolution resolution,
  ) {
    final lines = <String>[];
    if (resolution.regularSlotCount > 0) {
      lines.add(
        '${CollectionVocabulary.regularFigures} '
        '${resolution.regularOwnedCount} of ${resolution.regularSlotCount} '
        '${CollectionVocabulary.collected}',
      );
    }
    if (resolution.secretSlotCount > 0) {
      lines.add(
        '${CollectionVocabulary.secretFigures} '
        '${resolution.secretOwnedCount} of ${resolution.secretSlotCount} '
        '${CollectionVocabulary.collected}',
      );
    }
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  /// Optional factual secondary stat — Secret Figure whisper when complete.
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
      return '☆ Secret Figure still to find';
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
    if (owned > 0) {
      parts.add(CollectionVocabulary.countLabel(owned, CollectionVocabulary.figures));
    }
    if (wish > 0) {
      parts.add('$wish on ${CollectionVocabulary.wishlist}');
    }
    if (secrets.isNotEmpty && ownedSecrets < secrets.length) {
      final openSecrets = secrets.length - ownedSecrets;
      if (openSecrets > 0) {
        parts.add('${CollectionVocabulary.secretFigure} still to find');
      }
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
