import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Completion-ratio shelf mood (fallback when taxonomy coverage is sparse).
String legacyShelfMoodLine(CollectionSnapshot snap) {
  if (snap.shelfSeries.isEmpty) return '';

  final avg = snap.averageCompletionPercent;
  final seriesCount = snap.shelfSeries.length;
  final allFiguresOwned = snap.shelfSeries.every((s) {
    final p = progressForSeries(s, snap.figureStates);
    return s.figureCount > 0 && p.owned >= s.figureCount;
  });

  if (allFiguresOwned && seriesCount > 0) {
    return seriesCount == 1
        ? 'Every figure in this series has found its place.'
        : 'Every tracked figure on this shelf has found its place.';
  }
  if (avg >= 90) return 'Regular Progress is close to Complete.';
  if (avg >= 70) return 'Your shelf is coming together beautifully.';
  if (avg >= 40) return 'Room to grow -- each pull adds character.';
  return 'Still growing.';
}
