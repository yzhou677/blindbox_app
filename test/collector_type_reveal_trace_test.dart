import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_evolution_gate.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One real reveal execution: Loyalist title under 4.0 policy, same shelf,
/// 5.0 scoreboard prefers another winner — prints every gate value.
void main() {
  test('trace: version upgrade reveal keeps or evolves Loyalist', () {
    final series = [
      for (final (id, brand, ip) in [
        ('s1', 'pop_mart', 'the_monsters'),
        ('s2', 'toptoy', 'hirono'),
        ('s3', 'sonny', 'sonny_angel'),
      ])
        ShelfSeries(
          id: id,
          name: 'Series $id',
          brand: brand,
          ipName: ip,
          figures: [
            for (var i = 0; i < 3; i++)
              ShelfFigure(
                id: '${id}_$i',
                seriesId: id,
                name: 'F$i',
                rarity: 'Regular',
                isSecret: false,
              ),
          ],
          shelfAccent: const Color(0xFFE4F2EA),
          taxonomyBrandId: brand,
          taxonomyIpId: ip,
          catalogTemplateId: 'catalog_$id',
        ),
    ];
    final states = <String, TrackedFigure>{
      for (final s in series)
        for (final f in s.figures.take(1))
          f.id: TrackedFigure(
            figureId: f.id,
            state: FigureCollectionState.owned,
          ),
    };
    final snap = CollectionSnapshot(shelfSeries: series, figureStates: states);
    final now = DateTime(2026, 7, 12);
    final challenger = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: now,
    );

    // --- 1. Resolver output ---
    final ranked = challenger.scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final buf = StringBuffer()
      ..writeln('## 1. Resolver output')
      ..writeln('winner: ${challenger.archetypeId.name}')
      ..writeln('winnerScore: ${challenger.score}')
      ..writeln('confidence: ${challenger.confidence}');
    var runnerUpId = '';
    var runnerUpScore = 0.0;
    for (final e in ranked) {
      if (e.key == challenger.archetypeId) continue;
      if (e.value > runnerUpScore) {
        runnerUpScore = e.value;
        runnerUpId = e.key.name;
      }
    }
    buf.writeln('runner-up: $runnerUpId ($runnerUpScore)');
    buf.writeln('full scoreboard:');
    for (final e in ranked) {
      if (e.value <= 0) continue;
      buf.writeln('  ${e.key.name}: ${e.value}');
    }

    final previous = CollectorTypeIdentity(
      archetypeId: CollectorTypeArchetypeId.loyalist,
      revealedAt: DateTime(2026, 7, 11), // within soft cooldown
      signatureHash: challenger.signatureHash, // SAME shelf
      stats: const CollectorTypeStats(
        totalOwned: 3,
        totalWishlist: 0,
        trackedSeries: 3,
        completionPercent: 33,
        secretOwned: 0,
        secretSlots: 0,
        brandBreakdown: {},
        topSeries: [],
        customSeriesRatio: 0,
      ),
      reasonKey: CollectorTypeReasonKey.dominantUniverse,
    );

    buf
      ..writeln()
      ..writeln('## 2. Input to shouldEvolve()')
      ..writeln('Previous identity:')
      ..writeln('  archetype: ${previous.archetypeId.name}')
      ..writeln('  confidence: (not on Identity; only on RevealRecord)')
      ..writeln('  signature: ${previous.signatureHash}')
      ..writeln('  revealedAt: ${previous.revealedAt}')
      ..writeln('  previousResolverVersion: 4.0')
      ..writeln('Candidate:')
      ..writeln('  archetype: ${challenger.archetypeId.name}')
      ..writeln('  confidence: ${challenger.confidence}')
      ..writeln('  signature: ${challenger.signatureHash}')
      ..writeln('  currentResolverVersion: $kCollectorTypeResolverVersion');

    final sameType =
        challenger.archetypeId == previous.archetypeId;
    final sameSignature =
        challenger.signatureHash == previous.signatureHash;
    const previousResolverVersion = '4.0';
    final resolverChanged =
        previousResolverVersion != kCollectorTypeResolverVersion;
    final previousScore =
        challenger.scores[previous.archetypeId] ?? 0.0;
    final margin = challenger.score - previousScore;
    final sinceReveal = now.difference(previous.revealedAt);
    final inCooldown = sinceReveal < kCollectorTypeEvolutionSoftCooldown;
    final requiredMargin = inCooldown
        ? kCollectorTypeEvolutionScoreMargin +
            kCollectorTypeEvolutionCooldownExtraMargin
        : kCollectorTypeEvolutionScoreMargin;
    final marginEnough = margin >= requiredMargin;

    // Legacy gate (before signature/version fix): sameSignature alone returns false.
    final legacyStill = !sameType && sameSignature;

    buf
      ..writeln()
      ..writeln('## 3. Every gate (actual values)')
      ..writeln('sameType = $sameType '
          '(${challenger.archetypeId.name} == ${previous.archetypeId.name})')
      ..writeln('sameSignature = $sameSignature')
      ..writeln('resolverChanged = $resolverChanged '
          '($previousResolverVersion -> $kCollectorTypeResolverVersion)')
      ..writeln('previousScoreOnBoard = $previousScore')
      ..writeln('challengerScore = ${challenger.score}')
      ..writeln('margin = $margin '
          '(need >= $requiredMargin; inCooldown=$inCooldown)')
      ..writeln('confidence (informational only) = ${challenger.confidence}')
      ..writeln('cooldown = $inCooldown (sinceReveal=$sinceReveal)')
      ..writeln('marginEnough = $marginEnough')
      ..writeln('legacySameSignatureBlocks = $legacyStill');

    final evolved = shouldEvolve(
      previous: previous,
      challenger: challenger,
      snapshot: snap,
      now: now,
      previousResolverVersion: previousResolverVersion,
    );

    buf
      ..writeln()
      ..writeln('## 4. Branch')
      ..writeln('shouldEvolve() => $evolved')
      ..writeln(
        evolved
            ? 'ViewModel: return candidate '
                '(collector_type_view_model.dart evolved branch ~L77-87)'
            : 'ViewModel: return previous archetype (Still) '
                '(collector_type_view_model.dart else ~L88-98)',
      )
      ..writeln()
      ..writeln('## 5. sameSignature vs resolverVersion')
      ..writeln(
        'sameSignature alone must NOT Still after 4.0→5.0. '
        'Also skip confidence/cooldown hysteresis when resolverChanged.',
      );

    // ignore: avoid_print
    print(buf.toString());

    expect(sameSignature, isTrue);
    expect(resolverChanged, isTrue);
    expect(sameType, isFalse);
    expect(challenger.confidence < 0.55, isTrue); // informational; not a gate
    expect(evolved, isTrue);
  });
}
