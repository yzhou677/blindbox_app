import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';

/// One optional shelf-level harmony line (calm, non-prescriptive).
String? interpretShelfHarmonyLine({
  required CollectionSnapshot snap,
  required ShelfEmotionalProfile profile,
  required List<ShelfRelationshipInsight> insights,
}) {
  if (snap.shelfSeries.length < 2) return null;
  if (profile.interpretationConfidence == ShelfInterpretationConfidence.low) {
    return null;
  }

  if (insights.any((i) => i.kind == ShelfRelationshipKind.complementaryMood)) {
    return switch (profile.shelfMood) {
      ShelfMood.dreamy => 'Your collection blends dreamy and playful worlds',
      ShelfMood.playful => 'Playful lineups often sit beside softer worlds here',
      ShelfMood.settled => 'Your shelf mixes calm universes with room to wander',
      ShelfMood.chaseHunter => 'Rare pulls share the shelf with softer lineups',
      ShelfMood.growing => 'A few worlds are starting to echo each other',
    };
  }

  if (insights.any((i) => i.kind == ShelfRelationshipKind.sharedUniverse)) {
    return 'A universe keeps returning across your shelf';
  }

  if (profile.shelfMood == ShelfMood.dreamy &&
      profile.themeIncludes(ShelfEditorialTheme.multiUniverse)) {
    return 'Dreamy pastel lineups appear often together here';
  }

  return null;
}
