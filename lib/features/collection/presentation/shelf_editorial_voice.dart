import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/presentation/collection_memory_editorial.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_mood_legacy.dart';

/// Calm editorial copy for shelf emotional intelligence.
abstract final class ShelfEditorialVoice {
  static String shelfMoodLine(CollectionSnapshot snap) {
    final profile = interpretShelf(snap);
    if (profile.interpretationConfidence == ShelfInterpretationConfidence.low) {
      return legacyShelfMoodLine(snap);
    }
    final line = shelfInterpretationLine(profile);
    if (line.isNotEmpty) return line;
    return legacyShelfMoodLine(snap);
  }

  static String shelfInterpretationLine(ShelfEmotionalProfile profile) {
    if (profile.interpretationConfidence == ShelfInterpretationConfidence.low) {
      return '';
    }

    if (profile.themeIncludes(ShelfEditorialTheme.secrets) &&
        profile.secretOwnedCount >= 2) {
      return 'Secrets show up often in your collection';
    }

    return switch (profile.shelfMood) {
      ShelfMood.dreamy => 'Your shelf feels dreamy lately',
      ShelfMood.playful => 'A playful collecting mood on the shelf',
      ShelfMood.chaseHunter => 'You tend to chase the rare pulls',
      ShelfMood.settled when profile.themeIncludes(ShelfEditorialTheme.harmony) =>
        'Your shelf feels settled and complete',
      ShelfMood.settled => 'Your collection leans calm and curated',
      ShelfMood.growing => 'Room to grow — each series adds character',
    };
  }

  static String? sectionSubtitle(
    ShelfEmotionalProfile profile,
    List<ShelfRelationshipInsight> insights,
  ) {
    if (profile.interpretationConfidence == ShelfInterpretationConfidence.low) {
      return null;
    }
    if (insights.isNotEmpty &&
        insights.first.kind == ShelfRelationshipKind.sharedUniverse) {
      return 'A few worlds keep returning to your shelf';
    }
    if (profile.themeIncludes(ShelfEditorialTheme.multiUniverse)) {
      return 'You collect across a few universes';
    }
    return null;
  }

  static String? memoryWhisper(
    CollectionMemoryMoment moment, {
    CollectionSnapshot? snap,
  }) =>
      CollectionMemoryEditorial.whisperForMoment(moment, snap: snap);

  static String seriesCompleteBannerTitle({required bool chasesHome}) {
    return chasesHome
        ? 'Whole series — chase home'
        : 'This series feels complete';
  }

  static String seriesCompleteBannerSubtitle({required bool chasesHome}) {
    return chasesHome
        ? 'A rare, quiet moment for the shelf.'
        : 'Every figure has found its place here.';
  }
}
