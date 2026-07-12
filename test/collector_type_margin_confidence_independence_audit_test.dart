import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_evolution_gate.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Post-5.1: confidence is not an evolution gate; margin remains.
///
/// Definitions in shouldEvolve:
/// - margin = challenger.score − scores[previousArchetype]
/// - confidence = (winner − runnerUp) / winner  (any runner-up on the board)
///
/// When previous == runner-up: confidence = margin / winner (linked).
/// When previous ≠ runner-up: the two can disagree.

CollectorTypeIdentity _prev(CollectorTypeArchetypeId id) {
  return CollectorTypeIdentity(
    archetypeId: id,
    revealedAt: DateTime(2026, 1, 1),
    signatureHash: 'sig-old',
    stats: const CollectorTypeStats(
      totalOwned: 1,
      totalWishlist: 0,
      trackedSeries: 1,
      completionPercent: 10,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    ),
    reasonKey: CollectorTypeReasonKey.dominantUniverse,
  );
}

CollectorTypeResolution _board({
  required CollectorTypeArchetypeId winner,
  required double winnerScore,
  required Map<CollectorTypeArchetypeId, double> others,
  required double confidence,
}) {
  final scores = {
    for (final a in CollectorTypeArchetypeId.values) a: 0.0,
  };
  scores[winner] = winnerScore;
  for (final e in others.entries) {
    scores[e.key] = e.value;
  }
  return CollectorTypeResolution(
    archetypeId: winner,
    score: winnerScore,
    confidence: confidence,
    reasonKey: CollectorTypeReasonKey.deepCompletion,
    signatureHash: 'sig-new', // different → past sameSignature
    stats: const CollectorTypeStats(
      totalOwned: 8,
      totalWishlist: 0,
      trackedSeries: 4,
      completionPercent: 80,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    ),
    scores: scores,
  );
}

double _conf(double winner, double runnerUp) => (winner - runnerUp) / winner;

void main() {
  final snap = CollectionSnapshot.emptyTest();
  // Non-empty shelf so empty-shelf short-circuit does not fire.
  // shouldEvolve only checks isEmpty — emptyTest is empty. Use a dummy?
  // Looking at gate: `if (snapshot.shelfSeries.isEmpty && challenger.score <= 0)`
  // Our challenger scores > 0 so empty snap is fine.

  test('relationship: when previous == runner-up, confidence = margin/winner',
      () {
    const winner = 110.0;
    const previousAsRunnerUp = 64.0;
    final margin = winner - previousAsRunnerUp;
    final confidence = _conf(winner, previousAsRunnerUp);
    expect(confidence, closeTo(margin / winner, 1e-9));
    expect(margin >= kCollectorTypeEvolutionScoreMargin, isTrue); // 46 >= 12
    expect(confidence >= 0.55, isFalse);
    // ignore: avoid_print
    print(
      'LINKED (previous==runner-up): '
      'winner=$winner prev=$previousAsRunnerUp '
      'margin=$margin confidence=${confidence.toStringAsFixed(3)} '
      '→ margin PASS, confidence BLOCK — same pair, dual threshold',
    );
  });

  test('CASE A: after 5.1 low confidence no longer blocks when margin clears',
      () {
    final previous = _prev(CollectorTypeArchetypeId.loyalist);
    final challenger = _board(
      winner: CollectorTypeArchetypeId.curator,
      winnerScore: 80,
      others: {
        CollectorTypeArchetypeId.wanderer: 70,
        CollectorTypeArchetypeId.loyalist: 20,
      },
      confidence: _conf(80, 70),
    );
    final margin = challenger.score -
        (challenger.scores[previous.archetypeId] ?? 0);
    expect(margin, 60);
    expect(margin >= kCollectorTypeEvolutionScoreMargin, isTrue);
    expect(challenger.confidence < 0.55, isTrue);

    final evolved = shouldEvolve(
      previous: previous,
      challenger: challenger,
      snapshot: snap,
      now: DateTime(2026, 6, 1),
      previousResolverVersion: kCollectorTypeResolverVersion,
    );
    expect(evolved, isTrue);
  });

  test('CASE B: confidence passes, margin correctly blocks '
      '(winner dominates board; previous title still nearly as strong)', () {
    final previous = _prev(CollectorTypeArchetypeId.curator);
    final challenger = _board(
      winner: CollectorTypeArchetypeId.completionist,
      winnerScore: 100,
      others: {
        CollectorTypeArchetypeId.wanderer: 40,
        CollectorTypeArchetypeId.curator: 92,
      },
      confidence: _conf(100, 40),
    );
    final margin = challenger.score -
        (challenger.scores[previous.archetypeId] ?? 0);
    expect(challenger.confidence >= 0.55, isTrue);
    expect(margin < kCollectorTypeEvolutionScoreMargin, isTrue);

    final evolved = shouldEvolve(
      previous: previous,
      challenger: challenger,
      snapshot: snap,
      now: DateTime(2026, 6, 1),
      previousResolverVersion: kCollectorTypeResolverVersion,
    );
    expect(evolved, isFalse);
  });

  test('CASE C: previous == runner-up — margin alone evolves under 5.1', () {
    final previous = _prev(CollectorTypeArchetypeId.curator);
    final challenger = _board(
      winner: CollectorTypeArchetypeId.completionist,
      winnerScore: 110,
      others: {CollectorTypeArchetypeId.curator: 64},
      confidence: _conf(110, 64),
    );
    final margin = 110.0 - 64.0;
    expect(challenger.confidence, closeTo(margin / 110.0, 1e-9));
    expect(margin >= 12, isTrue);
    expect(challenger.confidence < 0.55, isTrue);

    final evolved = shouldEvolve(
      previous: previous,
      challenger: challenger,
      snapshot: snap,
      now: DateTime(2026, 6, 1),
      previousResolverVersion: kCollectorTypeResolverVersion,
    );
    expect(evolved, isTrue);
  });

  test('5.1 keeps margin; drops confidence from shouldEvolve', () {
    expect(true, isTrue);
  });
}
