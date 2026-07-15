import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_resolve.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveReasonKey', () {
    test('heals Loyalist + stillUnfolding to dominantUniverse', () {
      expect(
        effectiveReasonKey(
          archetypeId: CollectorTypeArchetypeId.loyalist,
          reasonKey: CollectorTypeReasonKey.stillUnfolding,
        ),
        CollectorTypeReasonKey.dominantUniverse,
      );
      expect(
        CollectorTypeCopy.becauseLineFor(
          CollectorTypeIdentity(
            archetypeId: CollectorTypeArchetypeId.loyalist,
            revealedAt: DateTime(2026, 1, 1),
            signatureHash: 'x',
            stats: const CollectorTypeStats(
              totalOwned: 1,
              totalWishlist: 0,
              trackedSeries: 1,
              completedSeriesCount: 0,
              masterCompleteSeriesCount: 0,
              masterEligibleSeriesCount: 0,
              completionPercent: 10,
              secretOwned: 0,
              secretSlots: 0,
              brandBreakdown: {},
              topSeries: [],
              customSeriesRatio: 0,
            ),
            reasonKey: CollectorTypeReasonKey.stillUnfolding,
          ),
        ),
        'Because one universe has the strongest presence in this reveal.',
      );
    });

    test('keeps stillUnfolding for Wanderer', () {
      expect(
        effectiveReasonKey(
          archetypeId: CollectorTypeArchetypeId.wanderer,
          reasonKey: CollectorTypeReasonKey.stillUnfolding,
        ),
        CollectorTypeReasonKey.stillUnfolding,
      );
    });

    test('preserves non-default reason keys', () {
      expect(
        effectiveReasonKey(
          archetypeId: CollectorTypeArchetypeId.loyalist,
          reasonKey: CollectorTypeReasonKey.curiousSpread,
        ),
        CollectorTypeReasonKey.curiousSpread,
      );
    });
  });

  group('CollectorTypeResolution.reasonKeyFor', () {
    const stats = CollectorTypeStats(
      totalOwned: 1,
      totalWishlist: 0,
      trackedSeries: 1,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
      masterEligibleSeriesCount: 0,
      completionPercent: 10,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );

    test('Still path uses scored reason for kept archetype', () {
      final resolution = CollectorTypeResolution(
        archetypeId: CollectorTypeArchetypeId.hunter,
        score: 40,
        confidence: 0.2,
        reasonKey: CollectorTypeReasonKey.manySecrets,
        signatureHash: 'h',
        stats: stats,
        scores: const {},
        reasons: {
          CollectorTypeArchetypeId.loyalist:
              CollectorTypeReasonKey.dominantUniverse,
          CollectorTypeArchetypeId.hunter: CollectorTypeReasonKey.manySecrets,
        },
      );

      expect(
        resolution.reasonKeyFor(CollectorTypeArchetypeId.loyalist),
        CollectorTypeReasonKey.dominantUniverse,
      );
    });

    test('falls back to canonical when archetype missing from reasons', () {
      final resolution = CollectorTypeResolution(
        archetypeId: CollectorTypeArchetypeId.hunter,
        score: 40,
        confidence: 0.2,
        reasonKey: CollectorTypeReasonKey.manySecrets,
        signatureHash: 'h',
        stats: stats,
        scores: const {},
        reasons: const {},
      );

      expect(
        resolution.reasonKeyFor(CollectorTypeArchetypeId.loyalist),
        CollectorTypeReasonKey.dominantUniverse,
      );
    });

    test('becauseLineForRecord matches becauseLineFor for same key', () {
      final identity = CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.loyalist,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'x',
        stats: stats,
        reasonKey: CollectorTypeReasonKey.stillUnfolding,
      );
      final record = CollectorTypeRevealRecord(
        archetypeId: identity.archetypeId,
        revealedAt: identity.revealedAt,
        signatureHash: identity.signatureHash,
        reasonKey: identity.displayReasonKey,
        score: 72,
        confidence: 0.4,
      );
      expect(
        CollectorTypeCopy.becauseLineFor(identity),
        CollectorTypeCopy.becauseLineForRecord(record),
      );
      expect(
        CollectorTypeCopy.becauseLineForRecord(record),
        'Because one universe has the strongest presence in this reveal.',
      );
    });
  });
}
