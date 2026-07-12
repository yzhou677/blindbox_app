import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_evolution_gate.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';

CollectorTypeIdentity _identity({
  required CollectorTypeArchetypeId id,
  required String signature,
  DateTime? revealedAt,
}) {
  return CollectorTypeIdentity(
    archetypeId: id,
    revealedAt: revealedAt ?? DateTime(2026, 1, 1),
    signatureHash: signature,
    stats: const CollectorTypeStats(
      totalOwned: 4,
      totalWishlist: 0,
      trackedSeries: 2,
      completionPercent: 50,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    ),
    reasonKey: CollectorTypeReasonKey.dominantUniverse,
  );
}

CollectorTypeResolution _challenger({
  required CollectorTypeArchetypeId id,
  required double score,
  required double previousTypeScore,
  required double confidence,
  required String signature,
  CollectorTypeArchetypeId previousType = CollectorTypeArchetypeId.loyalist,
}) {
  final scores = {
    for (final a in CollectorTypeArchetypeId.values) a: 0.0,
  };
  scores[previousType] = previousTypeScore;
  scores[id] = score;
  return CollectorTypeResolution(
    archetypeId: id,
    score: score,
    confidence: confidence,
    reasonKey: CollectorTypeReasonKey.intentionalSpread,
    signatureHash: signature,
    stats: const CollectorTypeStats(
      totalOwned: 8,
      totalWishlist: 0,
      trackedSeries: 4,
      completionPercent: 40,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    ),
    scores: scores,
  );
}

void main() {
  final emptySnap = CollectionSnapshot.emptyTest();
  const policy = kCollectorTypeResolverVersion;

  test('same type never evolves', () {
    final previous = _identity(
      id: CollectorTypeArchetypeId.loyalist,
      signature: 'sig-a',
    );
    final challenger = _challenger(
      id: CollectorTypeArchetypeId.loyalist,
      score: 90,
      previousTypeScore: 80,
      confidence: 0.9,
      signature: 'sig-b',
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1),
        previousResolverVersion: policy,
      ),
      isFalse,
    );
  });

  test('tiny margin does not evolve (Loyalist 81 → Curator 82)', () {
    final previous = _identity(
      id: CollectorTypeArchetypeId.loyalist,
      signature: 'sig-a',
      revealedAt: DateTime(2026, 1, 1),
    );
    final challenger = _challenger(
      id: CollectorTypeArchetypeId.curator,
      score: 82,
      previousTypeScore: 81,
      confidence: 0.9,
      signature: 'sig-b',
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1),
        previousResolverVersion: policy,
      ),
      isFalse,
    );
  });

  test('clear margin + signature change evolves', () {
    final previous = _identity(
      id: CollectorTypeArchetypeId.loyalist,
      signature: 'sig-a',
      revealedAt: DateTime(2026, 1, 1),
    );
    final challenger = _challenger(
      id: CollectorTypeArchetypeId.curator,
      score: 94,
      previousTypeScore: 80,
      confidence: 0.7,
      signature: 'sig-b',
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1),
        previousResolverVersion: policy,
      ),
      isTrue,
    );
  });

  test('low confidence does not block evolution when margin clears', () {
    // 5.1: confidence stays on Resolution but is not an evolution gate.
    // Real 5.0 shape: winner 110, previous=runner-up 64 → conf≈0.42, margin=46.
    final previous = _identity(
      id: CollectorTypeArchetypeId.curator,
      signature: 'sig-a',
      revealedAt: DateTime(2026, 1, 1),
    );
    final challenger = _challenger(
      id: CollectorTypeArchetypeId.completionist,
      score: 110,
      previousTypeScore: 64,
      confidence: 0.418,
      signature: 'sig-b',
      previousType: CollectorTypeArchetypeId.curator,
    );
    expect(challenger.confidence < 0.55, isTrue);
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1),
        previousResolverVersion: policy,
      ),
      isTrue,
    );
  });

  test('identical signature blocks evolution when resolverVersion unchanged',
      () {
    final previous = _identity(
      id: CollectorTypeArchetypeId.loyalist,
      signature: 'sig-same',
      revealedAt: DateTime(2026, 1, 1),
    );
    final challenger = _challenger(
      id: CollectorTypeArchetypeId.curator,
      score: 94,
      previousTypeScore: 80,
      confidence: 0.9,
      signature: 'sig-same',
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1),
        previousResolverVersion: policy,
      ),
      isFalse,
    );
  });

  test('identical signature allows evolution when resolverVersion upgraded',
      () {
    final previous = _identity(
      id: CollectorTypeArchetypeId.loyalist,
      signature: 'sig-same',
      revealedAt: DateTime(2026, 1, 1),
    );
    final challenger = _challenger(
      id: CollectorTypeArchetypeId.curator,
      score: 94,
      previousTypeScore: 80,
      confidence: 0.2,
      signature: 'sig-same',
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1),
        previousResolverVersion: '5.0',
        currentResolverVersion: policy,
      ),
      isTrue,
    );
  });

  test('soft cooldown requires larger margin', () {
    final previous = _identity(
      id: CollectorTypeArchetypeId.loyalist,
      signature: 'sig-a',
      revealedAt: DateTime(2026, 6, 1, 10),
    );
    final challenger = _challenger(
      id: CollectorTypeArchetypeId.curator,
      score: 93,
      previousTypeScore: 80, // margin 13 — clears base 12, not cooldown 20
      confidence: 0.9,
      signature: 'sig-b',
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1, 12),
        previousResolverVersion: policy,
      ),
      isFalse,
    );
    final strong = _challenger(
      id: CollectorTypeArchetypeId.curator,
      score: 101,
      previousTypeScore: 80, // margin 21
      confidence: 0.9,
      signature: 'sig-b',
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: strong,
        snapshot: emptySnap,
        now: DateTime(2026, 6, 1, 12),
        previousResolverVersion: policy,
      ),
      isTrue,
    );
  });

  test('identical signature allows evolution when previous title scores 0', () {
    final previous = _identity(
      id: CollectorTypeArchetypeId.loyalist,
      signature: 'sig-same',
      revealedAt: DateTime(2026, 7, 11),
    );
    final scores = {
      for (final a in CollectorTypeArchetypeId.values) a: 0.0,
    };
    scores[CollectorTypeArchetypeId.curator] = 64;
    scores[CollectorTypeArchetypeId.wanderer] = 51;
    final challenger = CollectorTypeResolution(
      archetypeId: CollectorTypeArchetypeId.curator,
      score: 64,
      confidence: 0.2,
      reasonKey: CollectorTypeReasonKey.intentionalSpread,
      signatureHash: 'sig-same',
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
      scores: scores,
    );
    expect(
      shouldEvolve(
        previous: previous,
        challenger: challenger,
        snapshot: emptySnap,
        now: DateTime(2026, 7, 12),
        previousResolverVersion: policy,
      ),
      isTrue,
    );
  });
}
