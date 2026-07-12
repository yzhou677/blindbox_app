import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';

/// Minimum score margin a challenger must beat the previous type by (on the
/// current shelf scoreboard) before evolution is allowed.
const double kCollectorTypeEvolutionScoreMargin = 12;

/// Soft cooldown: within this window, require a larger margin to evolve.
const Duration kCollectorTypeEvolutionSoftCooldown = Duration(hours: 24);

/// Extra margin required during [kCollectorTypeEvolutionSoftCooldown].
const double kCollectorTypeEvolutionCooldownExtraMargin = 8;

/// Single product gate for Collector Type evolution on an **unchanged** shelf.
///
/// Used only when [computeCollectorTypeNeedsReveal] is **false** (signature /
/// policy already match). Prevents identity churn on repeated Reveal.
///
/// When `needsReveal == true`, [CollectorTypeViewModel.requestReveal] must
/// persist the resolver candidate directly — this gate must not run for title
/// selection (signature invalidation must not decide the reveal result).
///
/// Answers (unchanged shelf only): has the challenger earned the title from
/// the **current identity** via scoreboard **margin** (+ cooldown)? Does
/// **not** use Resolution.confidence.
///
/// Named policy constants below — bump
/// [kCollectorTypeResolverVersion] when these change.
bool shouldEvolve({
  required CollectorTypeIdentity previous,
  required CollectorTypeResolution challenger,
  required CollectionSnapshot snapshot,
  DateTime? now,
  String? previousResolverVersion,
  String currentResolverVersion = kCollectorTypeResolverVersion,
}) {
  final resolverChanged = previousResolverVersion == null ||
      previousResolverVersion.isEmpty ||
      previousResolverVersion != currentResolverVersion;
  final sameSignature =
      challenger.signatureHash == previous.signatureHash;
  final previousScore = challenger.scores[previous.archetypeId] ?? 0;
  final previousAbsentFromBoard = previousScore <= 0;
  final current = now ?? DateTime.now();
  final inCooldown =
      current.difference(previous.revealedAt) < kCollectorTypeEvolutionSoftCooldown;

  // Same title is a refresh, not an evolution.
  if (challenger.archetypeId == previous.archetypeId) {
    return false;
  }

  // No structural shelf change → do not change identity — unless:
  // - resolver policy changed, or
  // - the previous title no longer scores on the current board (stale Still
  //   after a policy reinterpretation that already stamped the new version).
  if (sameSignature && !resolverChanged && !previousAbsentFromBoard) {
    return false;
  }

  // Touch snapshot so the parameter stays part of the live contract.
  if (snapshot.shelfSeries.isEmpty && challenger.score <= 0) {
    return false;
  }

  final margin = challenger.score - previousScore;
  if (margin < kCollectorTypeEvolutionScoreMargin) {
    return false;
  }

  // Policy reinterpretation: version bump, or previous title is absent from
  // today's scoreboard — challenger already cleared base margin.
  if (resolverChanged || previousAbsentFromBoard) {
    return true;
  }

  if (inCooldown) {
    final required = kCollectorTypeEvolutionScoreMargin +
        kCollectorTypeEvolutionCooldownExtraMargin;
    return margin >= required;
  }

  return true;
}
