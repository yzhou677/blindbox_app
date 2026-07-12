import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';

/// Display copy for Collection Insights and Collector Type reveal.
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
  static const String entryCta = 'Reveal collector type';
  static const String entryRevealedPrefix = 'Your collector type';

  static const String journeyTitle = 'Collector journey';
  static const String journeySubtitle =
      'How your shelf story has unfolded over time.';
  static const String journeyStartedLabel = 'Started';
  static const String journeyExploredLabel = 'Explored';

  /// Stable empty value for [journeyStartedLabel] when memory has no start date.
  static const String journeyStartedPending = '—';

  /// Localized “Because…” line from a resolver [CollectorTypeReasonKey].
  /// Qualitative only — never interpolate live percentages here.
  static String becauseLine(CollectorTypeReasonKey key) {
    return switch (key) {
      CollectorTypeReasonKey.stillUnfolding =>
        'Because your shelf is still finding its shape.',
      CollectorTypeReasonKey.curiousSpread =>
        'Because curiosity keeps leading you into new corners.',
      CollectorTypeReasonKey.dominantUniverse =>
        'Because your shelf keeps returning to the same universe.',
      CollectorTypeReasonKey.highWishlist =>
        'Because your Wishlist is where the story begins.',
      CollectorTypeReasonKey.wishlistDominates =>
        'Because more lives on your Wishlist than on the shelf.',
      CollectorTypeReasonKey.manySecrets =>
        'Because Secret Figures keep drawing your focus.',
      CollectorTypeReasonKey.fortunateSecrets =>
        'Because fortune seems to find your Secret pulls.',
      CollectorTypeReasonKey.deepCompletion =>
        'Because finishing series is where you find calm.',
      CollectorTypeReasonKey.nearCompletion =>
        'Because you keep bringing series to the edge of complete.',
      CollectorTypeReasonKey.intentionalSpread =>
        'Because you shape a gallery across many worlds.',
      CollectorTypeReasonKey.compactShelf =>
        'Because a small shelf, carefully chosen, is enough.',
      CollectorTypeReasonKey.livingArchive =>
        'Because notes and covers turn your shelf into an archive.',
      CollectorTypeReasonKey.composedShelf =>
        'Because presentation is part of how you collect.',
      CollectorTypeReasonKey.freshDrops =>
        'Because fresh drops land on your shelf while they are still new.',
    };
  }
}
