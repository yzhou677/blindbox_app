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
      CollectionMemoryMomentKind.dominantUniverse
          when moment.universeLabel != null =>
        '${moment.universeLabel} has the strongest universe presence',
      CollectionMemoryMomentKind.dominantUniverse =>
        'One universe has the strongest presence',
      CollectionMemoryMomentKind.shelfMilestone =>
        'Your shelf has no in-progress series right now',
      CollectionMemoryMomentKind.longLovedUniverse
          when moment.universeLabel != null =>
        '${moment.universeLabel} is the earliest recorded universe',
      CollectionMemoryMomentKind.longLovedUniverse =>
        'One universe has the earliest recorded shelf date',
      CollectionMemoryMomentKind.shelfEvolution => null,
      CollectionMemoryMomentKind.shelfGrowing =>
        'Your shelf has recorded growth over time',
    };
  }

  static String? whisperForEvolution(CollectionEvolution evolution) {
    return switch (evolution.kind) {
      CollectionEvolutionKind.moodSoftened =>
        'Softer series signals increased in the latest comparison',
      CollectionEvolutionKind.moodBrightened =>
        'Playful series signals increased in the latest comparison',
      CollectionEvolutionKind.secretsEmerging =>
        'Secret Figure ownership increased in the latest comparison',
      CollectionEvolutionKind.universeShift =>
        'A new universe appeared in the latest comparison',
    };
  }

  static String? _recentCompletionWhisper(
    CollectionMemoryMoment moment,
    CollectionSnapshot? snap,
  ) {
    final name = moment.seriesName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        snap != null &&
        moment.seriesId != null) {
      for (final series in snap.shelfSeries) {
        if (series.id != moment.seriesId) continue;
        if (resolveSeriesCompletion(
          series,
          snap.figureStates,
        ).isMasterComplete) {
          return '$name is your latest Master Complete series';
        }
        break;
      }
      return '$name is your latest Complete series';
    }
    if (name != null && name.isNotEmpty) {
      return '$name is your latest Complete series';
    }
    return 'A series recently reached Complete';
  }
}
