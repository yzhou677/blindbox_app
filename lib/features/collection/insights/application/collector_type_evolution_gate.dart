import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';

/// Minimum score margin a challenger must beat the previous type by (on the
/// current shelf scoreboard) before evolution is allowed.
const double kCollectorTypeEvolutionScoreMargin = 12;

/// Minimum internal confidence required to accept an evolution.
///
/// Confidence is never shown in UI — only this gate consumes it.
const double kCollectorTypeEvolutionMinConfidence = 0.55;

/// Soft cooldown: within this window, require a larger margin to evolve.
const Duration kCollectorTypeEvolutionSoftCooldown = Duration(hours: 24);

/// Extra margin required during [kCollectorTypeEvolutionSoftCooldown].
const double kCollectorTypeEvolutionCooldownExtraMargin = 8;

/// Single product gate for Collector Type evolution.
///
/// All future signals (margin, confidence, time, signature) live here so
/// Reveal / Hero / Analytics never scatter `if` chains.
///
/// [snapshot] is part of the stable contract for future gate inputs
/// (velocity, custom mix, …) without changing call sites.
bool shouldEvolve({
  required CollectorTypeIdentity previous,
  required CollectorTypeResolution challenger,
  required CollectionSnapshot snapshot,
  DateTime? now,
}) {
  // Same title is a refresh, not an evolution.
  if (challenger.archetypeId == previous.archetypeId) return false;

  // No structural shelf change → do not change identity.
  if (challenger.signatureHash == previous.signatureHash) return false;

  // Touch snapshot so the parameter stays part of the live contract.
  if (snapshot.shelfSeries.isEmpty && challenger.score <= 0) return false;

  final previousScore = challenger.scores[previous.archetypeId] ?? 0;
  final margin = challenger.score - previousScore;
  if (margin < kCollectorTypeEvolutionScoreMargin) return false;

  // Low confidence: prefer Still even when margin clears the floor.
  if (challenger.confidence < kCollectorTypeEvolutionMinConfidence) {
    return false;
  }

  final current = now ?? DateTime.now();
  final sinceReveal = current.difference(previous.revealedAt);
  if (sinceReveal < kCollectorTypeEvolutionSoftCooldown) {
    final required = kCollectorTypeEvolutionScoreMargin +
        kCollectorTypeEvolutionCooldownExtraMargin;
    if (margin < required) return false;
  }

  return true;
}
