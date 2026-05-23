import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_evolution.dart';
import 'package:blindbox_app/features/collection/domain/shelf_era.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';

/// Compares persisted [priorEra] with the live shelf profile.
CollectionEvolution? interpretCollectionEvolution({
  required CollectionSnapshot snap,
  required ShelfEra? priorEra,
}) {
  if (priorEra == null || snap.shelfSeries.length < 2) return null;

  final profile = interpretShelf(snap);
  if (profile.interpretationConfidence == ShelfInterpretationConfidence.low) {
    return null;
  }

  if (priorEra.shelfMood != profile.shelfMood) {
    final kind = _moodShiftKind(priorEra.shelfMood, profile.shelfMood);
    if (kind != null) {
      return CollectionEvolution(
        kind: kind,
        priorEra: priorEra,
        currentMood: profile.shelfMood,
      );
    }
  }

  if (priorEra.dominantIpId != null &&
      profile.dominantIpId != null &&
      priorEra.dominantIpId != profile.dominantIpId &&
      profile.interpretationConfidence.index >=
          ShelfInterpretationConfidence.medium.index) {
    return CollectionEvolution(
      kind: CollectionEvolutionKind.universeShift,
      priorEra: priorEra,
      currentMood: profile.shelfMood,
    );
  }

  if (profile.secretOwnedCount >= 2 &&
      priorEra.secretOwnedCount == 0 &&
      profile.hasSecretAffinity) {
    return CollectionEvolution(
      kind: CollectionEvolutionKind.secretsEmerging,
      priorEra: priorEra,
      currentMood: profile.shelfMood,
    );
  }

  return null;
}

CollectionEvolutionKind? _moodShiftKind(ShelfMood from, ShelfMood to) {
  const soft = {ShelfMood.dreamy, ShelfMood.settled};
  const bright = {ShelfMood.playful, ShelfMood.growing};
  if (soft.contains(to) && bright.contains(from)) {
    return CollectionEvolutionKind.moodSoftened;
  }
  if (bright.contains(to) && soft.contains(from)) {
    return CollectionEvolutionKind.moodBrightened;
  }
  return null;
}

/// Current shelf era from emotional interpreter (display / evolution baseline).
ShelfEra shelfEraFromProfile(ShelfEmotionalProfile profile, int seriesCount) {
  return ShelfEra(
    shelfMood: profile.shelfMood,
    seriesCount: seriesCount,
    secretOwnedCount: profile.secretOwnedCount,
    dominantIpId: profile.dominantIpId,
    recordedAt: DateTime.now(),
  );
}
