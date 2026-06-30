import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';

/// Curated collector-stage lines for the collection summary card.
abstract final class CollectionSummaryEditorial {
  static String shelfMoodLine(CollectionSnapshot snap) {
    final (completed, master) = countShelfCompletionTiers(snap);
    final stage = _stageFor(
      inCollection: snap.totalOwnedFigures,
      seriesOnShelf: snap.shelfSeries.length,
      completedSeries: completed,
      masterCompleteSeries: master,
    );
    final alt = snap.shelfSeries.length % 2;
    return switch (stage) {
      _CollectorStage.masterComplete => alt == 0
          ? 'Master Complete lineups are finding their place on your shelf.'
          : 'A quiet pride in series finished all the way through.',
      _CollectorStage.severalComplete => alt == 0
          ? 'Several series feel complete — your shelf is finding its rhythm.'
          : 'Completed lineups are becoming a steady part of your collection.',
      _CollectorStage.firstComplete => alt == 0
          ? 'Your first complete series is a gentle milestone.'
          : 'One series feels whole — room for more when you\'re ready.',
      _CollectorStage.growing => alt == 0
          ? 'Your collection is quietly taking shape.'
          : 'Each figure adds a little more character to the shelf.',
      _CollectorStage.beginning => alt == 0
          ? 'A shelf ready for its first lineup.'
          : 'Your collection is just getting started.',
    };
  }

  static _CollectorStage _stageFor({
    required int inCollection,
    required int seriesOnShelf,
    required int completedSeries,
    required int masterCompleteSeries,
  }) {
    if (masterCompleteSeries > 0) {
      return _CollectorStage.masterComplete;
    }
    if (completedSeries >= 2) {
      return _CollectorStage.severalComplete;
    }
    if (completedSeries == 1) {
      return _CollectorStage.firstComplete;
    }
    if (inCollection > 0 || seriesOnShelf > 0) {
      return _CollectorStage.growing;
    }
    return _CollectorStage.beginning;
  }
}

enum _CollectorStage {
  beginning,
  growing,
  firstComplete,
  severalComplete,
  masterComplete,
}

/// Summary metric labels — figure row vs series-progress row.
abstract final class CollectionSummaryLabels {
  static const figures = 'Figures';
  static const wishlist = 'Wishlist';
  static const seriesComplete = 'Series complete';
  static const masterComplete = 'Master Complete';
}
