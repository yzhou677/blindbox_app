import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_evolution.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';

/// Calm personal memory copy — reflective, not gamified.
abstract final class CollectionMemoryEditorial {
  static const Duration recentCompletionWindow = Duration(days: 21);
  static const Duration shelfGrowingMinAge = Duration(days: 90);

  static String? whisperForMoment(
    CollectionMemoryMoment moment, {
    CollectionSnapshot? snap,
  }) {
    return switch (moment.kind) {
      CollectionMemoryMomentKind.firstSecretOwned =>
        'Your first Secret Figure still lives on this shelf',
      CollectionMemoryMomentKind.recentlyCompletedLineup =>
        _recentCompletionWhisper(moment, snap),
      CollectionMemoryMomentKind.dominantUniverse when
            moment.universeLabel != null =>
        '${moment.universeLabel} keeps drawing you back',
      CollectionMemoryMomentKind.dominantUniverse =>
        'One universe keeps drawing you back',
      CollectionMemoryMomentKind.shelfMilestone =>
        'Every series on your shelf feels complete',
      CollectionMemoryMomentKind.longLovedUniverse when
            moment.universeLabel != null =>
        '${moment.universeLabel} has stayed with you the longest',
      CollectionMemoryMomentKind.longLovedUniverse =>
        'A universe has stayed with you the longest',
      CollectionMemoryMomentKind.shelfEvolution =>
        null,
      CollectionMemoryMomentKind.shelfGrowing =>
        'Your shelf has been quietly growing for a while',
    };
  }

  static String? whisperForEvolution(CollectionEvolution evolution) {
    return switch (evolution.kind) {
      CollectionEvolutionKind.moodSoftened =>
        'Your shelf has gradually become softer and dreamier',
      CollectionEvolutionKind.moodBrightened =>
        'Playful lineups have been appearing more often lately',
      CollectionEvolutionKind.secretsEmerging =>
        'Secret Figures have slowly become part of your collection',
      CollectionEvolutionKind.universeShift =>
        'A new universe has been finding its place on your shelf',
    };
  }

  static String? seriesReflection({
    required bool recentlyCompleted,
    required bool isComplete,
    required String seriesName,
  }) {
    if (recentlyCompleted && isComplete) {
      return '$seriesName was recently completed after a long search';
    }
    if (isComplete) {
      return 'This completed series has found its place on your shelf';
    }
    return null;
  }

  static String? _recentCompletionWhisper(
    CollectionMemoryMoment moment,
    CollectionSnapshot? snap,
  ) {
    final name = moment.seriesName?.trim();
    if (name != null && name.isNotEmpty && snap != null && moment.seriesId != null) {
      for (final series in snap.shelfSeries) {
        if (series.id != moment.seriesId) continue;
        if (resolveSeriesCompletion(series, snap.figureStates).isMasterComplete) {
          return '$name is your latest Master Complete series';
        }
        break;
      }
      return '$name is your latest completed series';
    }
    if (name != null && name.isNotEmpty) {
      return '$name is your latest completed series';
    }
    return 'A series was recently completed';
  }
}
