import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = CollectorTypeStats(
  totalOwned: 4,
  totalWishlist: 0,
  trackedSeries: 2,
  completedSeriesCount: 0,
  masterCompleteSeriesCount: 0,
  masterEligibleSeriesCount: 0,
  completionPercent: 40,
  secretOwned: 0,
  secretSlots: 0,
  brandBreakdown: {},
  topSeries: [],
  customSeriesRatio: 0,
);

void main() {
  test('fromResolvePass captures scoreboard snapshot for replay', () {
    final resolution = CollectorTypeResolution(
      archetypeId: CollectorTypeArchetypeId.loyalist,
      score: 72,
      confidence: 0.4,
      reasonKey: CollectorTypeReasonKey.dominantUniverse,
      signatureHash: 'sig-now',
      stats: _stats,
      scores: {
        CollectorTypeArchetypeId.loyalist: 72,
        CollectorTypeArchetypeId.hunter: 40,
      },
      reasons: {
        CollectorTypeArchetypeId.loyalist:
            CollectorTypeReasonKey.dominantUniverse,
      },
    );
    final identity = CollectorTypeIdentity(
      archetypeId: resolution.archetypeId,
      revealedAt: DateTime(2026, 7, 1),
      signatureHash: resolution.signatureHash,
      stats: resolution.stats,
      reasonKey: resolution.reasonKey,
    );
    final record = CollectorTypeRevealRecord.fromResolvePass(
      identity: identity,
      resolution: resolution,
      isEvolution: true,
    );

    expect(record.archetypeId, CollectorTypeArchetypeId.loyalist);
    expect(record.score, 72);
    expect(record.confidence, 0.4);
    expect(record.isEvolution, isTrue);
    expect(record.resolverVersion, kCollectorTypeResolverVersion);
    expect(record.reasonKey, CollectorTypeReasonKey.dominantUniverse);
    expect(
      CollectorTypeCopy.becauseLineForRecord(record),
      'Because one universe clearly defines your shelf.',
    );
  });

  test('Still path snapshots kept archetype score, not challenger winner', () {
    final resolution = CollectorTypeResolution(
      archetypeId: CollectorTypeArchetypeId.hunter,
      score: 80,
      confidence: 0.5,
      reasonKey: CollectorTypeReasonKey.manySecrets,
      signatureHash: 'sig',
      stats: _stats,
      scores: {
        CollectorTypeArchetypeId.hunter: 80,
        CollectorTypeArchetypeId.loyalist: 55,
      },
      reasons: {
        CollectorTypeArchetypeId.hunter: CollectorTypeReasonKey.manySecrets,
        CollectorTypeArchetypeId.loyalist:
            CollectorTypeReasonKey.dominantUniverse,
      },
    );
    // Gate kept Loyalist; identity differs from challenger winner.
    final identity = CollectorTypeIdentity(
      archetypeId: CollectorTypeArchetypeId.loyalist,
      revealedAt: DateTime(2026, 7, 2),
      signatureHash: 'sig',
      stats: _stats,
      reasonKey: CollectorTypeReasonKey.dominantUniverse,
    );
    final record = CollectorTypeRevealRecord.fromResolvePass(
      identity: identity,
      resolution: resolution,
      isEvolution: false,
    );

    expect(record.archetypeId, CollectorTypeArchetypeId.loyalist);
    expect(record.score, 55);
    expect(record.confidence, 0.5);
    expect(record.isEvolution, isFalse);
  });

  test('json round-trips score, confidence, and resolverVersion', () {
    final record = CollectorTypeRevealRecord(
      archetypeId: CollectorTypeArchetypeId.curator,
      revealedAt: DateTime(2026, 3, 1),
      signatureHash: 'h',
      reasonKey: CollectorTypeReasonKey.intentionalSpread,
      score: 61.5,
      confidence: 0.22,
      resolverVersion: kCollectorTypeResolverVersion,
      isEvolution: true,
    );
    final restored = CollectorTypeRevealRecord.fromJson(record.toJson());
    expect(restored.score, 61.5);
    expect(restored.confidence, 0.22);
    expect(restored.resolverVersion, kCollectorTypeResolverVersion);
    expect(restored.isEvolution, isTrue);

    final legacy = CollectorTypeRevealRecord.fromJson({
      'archetypeId': 'loyalist',
      'revealedAtMs': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'signatureHash': 'old',
    });
    expect(legacy.score, 0);
    expect(legacy.confidence, 0);
    expect(legacy.resolverVersion, '1.0');
    expect(legacy.reasonKey, CollectorTypeReasonKey.dominantUniverse);
    expect(legacy.isEvolution, isFalse);
  });
}
