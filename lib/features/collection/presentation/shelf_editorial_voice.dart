import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'package:blindbox_app/features/collection/presentation/collection_memory_editorial.dart';
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
      return '${profile.secretOwnedCount} Secret Figures are recorded in your collection';
    }

    return switch (profile.shelfMood) {
      ShelfMood.dreamy => 'Soft-toned series are a strong shelf signal',
      ShelfMood.playful => 'Playful series are a strong shelf signal',
      ShelfMood.chaseHunter => 'Secret Figures are a strong shelf signal',
      ShelfMood.settled
          when profile.themeIncludes(ShelfEditorialTheme.harmony) =>
        'Shared-universe signals are present on your shelf',
      ShelfMood.settled => 'Several series have reached Complete',
      ShelfMood.growing => 'Your shelf has in-progress series',
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
      return 'Multiple series share a universe';
    }
    if (profile.themeIncludes(ShelfEditorialTheme.multiUniverse)) {
      return 'Multiple universes are recorded on your shelf';
    }
    return null;
  }

  static String? memoryWhisper(
    CollectionMemoryMoment moment, {
    CollectionSnapshot? snap,
  }) => CollectionMemoryEditorial.whisperForMoment(moment, snap: snap);

  static String seriesCompleteBannerTitle(SeriesCompletionBannerState state) {
    return switch (state) {
      SeriesCompletionBannerState.completeNoSecrets => 'Collection Complete',
      SeriesCompletionBannerState.completeWithSecretsRemaining =>
        'Complete -- every Regular home',
      SeriesCompletionBannerState.masterComplete =>
        'Master Complete -- every figure home',
    };
  }

  static String seriesCompleteBannerSubtitle(
    SeriesCompletionBannerState state,
  ) {
    return switch (state) {
      SeriesCompletionBannerState.completeNoSecrets =>
        'Every figure has found its place.',
      SeriesCompletionBannerState.completeWithSecretsRemaining =>
        'Secret Figures can still be found later.',
      SeriesCompletionBannerState.masterComplete =>
        'Every Regular and Secret figure has found its place.',
    };
  }
}

enum SeriesCompletionBannerState {
  completeNoSecrets,
  completeWithSecretsRemaining,
  masterComplete,
}
