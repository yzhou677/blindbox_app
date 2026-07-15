import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';

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
      _CollectorStage.masterComplete => _masterCompleteShelfMoodLine(master),
      _CollectorStage.severalComplete =>
        alt == 0
            ? 'Several series have reached Complete.'
            : 'Completed Series includes Regular Complete and Master Complete.',
      _CollectorStage.firstComplete =>
        alt == 0
            ? 'One series has reached Complete.'
            : 'Completed Series includes Regular Complete and Master Complete.',
      _CollectorStage.growing =>
        alt == 0
            ? 'Your collection has in-progress series.'
            : 'Tracked figures are recorded on your shelf.',
      _CollectorStage.beginning =>
        alt == 0
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

  static String _masterCompleteShelfMoodLine(int masterCount) {
    return switch (masterCount) {
      1 => 'Your collection now includes a Master Complete series.',
      2 => 'Your collection now includes multiple Master Complete series.',
      _ => 'Your collection now includes $masterCount Master Complete series.',
    };
  }
}

enum _CollectorStage {
  beginning,
  growing,
  firstComplete,
  severalComplete,
  masterComplete,
}

/// Collection Summary metric labels — shelf activity (owned + wishlist intent).
///
/// Differs from Insights [InsightsAtAGlanceLabels]: Summary includes wishlist;
/// At a glance shows achievement tiers and secrets collected instead.
abstract final class CollectionSummaryLabels {
  static const figures = CollectionVocabulary.ownedFigures;
  static const wishlist = CollectionVocabulary.wishlistedFigures;
  static const seriesComplete = CollectionVocabulary.completedSeries;
  static const masterComplete = CollectionVocabulary.masterComplete;
}
