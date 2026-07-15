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
      'Collector Type summarizes patterns in your recorded collection.';

  static const String revealButton = 'Reveal collector type';
  static const String revealAgain = 'Refresh Collector Type';
  static const String analyzingLine = 'Reading your shelf…';

  /// Ceremonial first-reveal intro (event overlay — not hero copy).
  static const String revealCeremonyFirstIntro =
      'A new collector type snapshot is ready.';

  /// Ceremonial intro when the collector type itself has changed.
  static const String revealCeremonyEvolvedIntro =
      'Your collector type snapshot has changed.';

  static const String revealCeremonyContinue = 'Continue';

  static const String evolutionHint =
      'Your collection has changed since the last Collector Type reveal.';

  static const String staleInsightsMessage =
      'These insights reflect your previous reveal. Your collection has '
      'changed; refresh Collector Type to update them.';

  static const String staleInsightsMessageCompact =
      'These insights reflect your previous reveal.';

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
      'Stored collection milestones over time.';
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
        'Because no specialized shelf pattern qualified at this reveal.',
      CollectorTypeReasonKey.curiousSpread =>
        'Because no specialized shelf pattern qualified at this reveal.',
      CollectorTypeReasonKey.dominantUniverse =>
        'Because one universe has the strongest presence in this reveal.',
      CollectorTypeReasonKey.highWishlist =>
        'Because wishlist figures are a strong signal in this reveal.',
      CollectorTypeReasonKey.manySecrets =>
        'Because Secret Figures are a strong signal in this reveal.',
      CollectorTypeReasonKey.fortunateSecrets =>
        'Because Secret ownership is high for an early shelf.',
      CollectorTypeReasonKey.deepCompletion =>
        'Because completion is the strongest signal in this reveal.',
      CollectorTypeReasonKey.nearCompletion =>
        'Because many tracked series are close to Complete.',
      CollectorTypeReasonKey.intentionalSpread =>
        'Because multiple universes have meaningful representation in this reveal.',
      CollectorTypeReasonKey.compactShelf =>
        'Because this reveal is based on a small shelf.',
      CollectorTypeReasonKey.inventedWorlds =>
        'Because custom series are a strong signal in this reveal.',
      CollectorTypeReasonKey.freshDrops =>
        'Because recent-release series are a strong signal in this reveal.',
    };
  }
}
