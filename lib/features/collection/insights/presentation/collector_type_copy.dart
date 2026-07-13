import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';

/// Display copy for Collection Insights and Collector Type reveal.
///
/// Because copy pipeline (do not fork):
/// ```
/// Resolver → CollectorTypeIdentity.reasonKey → becauseLineFor(…) → UI
/// ```
/// Hero, Reveal ceremony, Reveal history, and Personality Memory / Timeline
/// must call [becauseLineFor] or [becauseLineForRecord] — never `switch` on
/// archetype for causal copy.
abstract final class CollectorTypeCopy {
  CollectorTypeCopy._();

  static const String screenTitle = 'Collection insights';
  static const String screenSubtitle =
      'A quiet read on how you collect — reveal when it feels right.';

  static const String revealButton = 'Reveal collector type';
  static const String revealAgain = 'Reveal again';
  static const String analyzingLine = 'Reading your shelf…';

  /// Ceremonial first-reveal intro (event overlay — not hero copy).
  static const String revealCeremonyFirstIntro =
      'Your shelf tells a new story.';

  /// Ceremonial intro when the collector type itself has changed.
  static const String revealCeremonyEvolvedIntro =
      'Your collecting style has evolved.';

  static const String revealCeremonyContinue = 'Continue';

  static const String evolutionHint =
      'Your collection has shifted — reveal again when you are ready.';

  static const String staleInsightsMessage =
      'These insights are from your last reveal. Your collection has '
      'changed — reveal again for an updated read.';

  static const String staleInsightsMessageCompact =
      'Insights below reflect your shelf at the last reveal.';

  static const String statsSectionTitle = 'At a glance';

  /// Achievement-focused snapshot at last reveal — not the Collection Summary
  /// wishlist row. Each label names what is counted (figures vs series vs secrets).
  static const String atAGlanceOwnedFigures = CollectionVocabulary.ownedFigures;
  static const String atAGlanceCompletedSeries =
      CollectionVocabulary.completedSeries;
  static const String atAGlanceMasterComplete =
      CollectionVocabulary.masterComplete;
  static const String atAGlanceSecretsCollected =
      CollectionVocabulary.secretsCollected;
  static const String entryCta = 'Reveal collector type';
  static const String entryRevealedPrefix = 'Your collector type';

  static const String journeyTitle = 'Collector journey';
  static const String journeySubtitle =
      'How your shelf story has unfolded over time.';
  static const String journeyStartedLabel = 'Started';
  static const String journeyExploredLabel = 'Explored';
  static const String journeyLatestMemoryLabel = 'Latest Memory';

  /// Moment titles — diary beats, not stats labels.
  static const String journeyMemoryMasterComplete = '👑 Master Complete';
  static const String journeyMemoryCompleted = 'Completed';
  static const String journeyMemoryFirstSecret = '✨ First Secret';

  /// Stable empty value for [journeyStartedLabel] when memory has no start date.
  static const String journeyStartedPending = '—';

  /// Sole UI entry for live identity “Because…” copy.
  static String becauseLineFor(CollectorTypeIdentity identity) {
    return becauseLine(identity.displayReasonKey);
  }

  /// Sole UI entry for historical reveal “Because…” (Timeline / Memory).
  static String becauseLineForRecord(CollectorTypeRevealRecord record) {
    return becauseLine(record.displayReasonKey);
  }

  /// Localized “Because…” from a stored [CollectorTypeReasonKey].
  /// Prefer [becauseLineFor] / [becauseLineForRecord] at UI boundaries.
  /// Qualitative only — never interpolate live percentages here.
  static String becauseLine(CollectorTypeReasonKey key) {
    return switch (key) {
      CollectorTypeReasonKey.stillUnfolding =>
        'Because your shelf is still discovering what defines it.',
      CollectorTypeReasonKey.curiousSpread =>
        'Because your shelf is still discovering what defines it.',
      CollectorTypeReasonKey.dominantUniverse =>
        'Because one universe clearly defines your shelf.',
      CollectorTypeReasonKey.highWishlist =>
        'Because you dream about what comes next more than what you already own.',
      CollectorTypeReasonKey.manySecrets =>
        'Because you actively hunt Secrets—and you catch them.',
      CollectorTypeReasonKey.fortunateSecrets =>
        'Because luck found you before hunting did.',
      CollectorTypeReasonKey.deepCompletion =>
        'Because completion defines your shelf.',
      CollectorTypeReasonKey.nearCompletion =>
        'Because most of your shelf is at the edge of complete.',
      CollectorTypeReasonKey.intentionalSpread =>
        'Because your shelf is a gallery of worlds you genuinely invest in.',
      CollectorTypeReasonKey.compactShelf =>
        'Because you keep a small, focused shelf and care deeply for what makes the cut.',
      CollectorTypeReasonKey.inventedWorlds =>
        'Because your own creations define your shelf.',
      CollectorTypeReasonKey.freshDrops =>
        'Because recent releases define your shelf.',
    };
  }
}
