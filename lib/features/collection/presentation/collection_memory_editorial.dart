import 'package:blindbox_app/features/collection/domain/collection_evolution.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';

/// Calm personal memory copy — reflective, not gamified.
abstract final class CollectionMemoryEditorial {
  static const Duration recentCompletionWindow = Duration(days: 21);
  static const Duration shelfGrowingMinAge = Duration(days: 90);

  static String? whisperForMoment(CollectionMemoryMoment moment) {
    return switch (moment.kind) {
      CollectionMemoryMomentKind.firstSecretOwned =>
        'Your first secret still lives on this shelf',
      CollectionMemoryMomentKind.recentlyCompletedLineup when
            moment.seriesName != null =>
        '${moment.seriesName} recently felt complete',
      CollectionMemoryMomentKind.recentlyCompletedLineup =>
        'A lineup recently felt complete',
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
        'Secrets have slowly become part of your collection language',
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
      return '$seriesName recently felt complete after a long search';
    }
    if (isComplete) {
      return 'This lineup has found its place on your shelf';
    }
    return null;
  }
}
