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
      ShelfMood.playful => 'Playful and soft-toned lineups are both present',
      ShelfMood.settled => 'Multiple calm-universe signals are present',
      ShelfMood.chaseHunter => 'Rare pulls share the shelf with softer lineups',
      ShelfMood.growing => 'Multiple related worlds are present',
    };
  }

  if (insights.any((i) => i.kind == ShelfRelationshipKind.sharedUniverse)) {
    return 'Multiple series share a universe';
  }

  if (profile.shelfMood == ShelfMood.dreamy &&
      profile.themeIncludes(ShelfEditorialTheme.multiUniverse)) {
    return 'Multiple soft-toned lineups are present';
  }

  return null;
}
