import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_display_stats.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_needs_reveal.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

CollectorTypeStats _stats({
  int completedSeriesCount = 0,
  int masterCompleteSeriesCount = 0,
  int masterEligibleSeriesCount = 0,
  int completionPercent = 40,
  int trackedSeries = 1,
}) {
  return CollectorTypeStats(
    totalOwned: 0,
    totalWishlist: 0,
    trackedSeries: trackedSeries,
    completedSeriesCount: completedSeriesCount,
    masterCompleteSeriesCount: masterCompleteSeriesCount,
    masterEligibleSeriesCount: masterEligibleSeriesCount,
    completionPercent: completionPercent,
    secretOwned: 0,
    secretSlots: 0,
    brandBreakdown: const {},
    topSeries: const [],
    customSeriesRatio: 0,
  );
}

void main() {
  group('collectorTypeStatsAreCurrent', () {
    test('false when version is missing or older', () {
      final json = {
        'completedSeriesCount': 1,
        'masterCompleteSeriesCount': 1,
        'masterEligibleSeriesCount': 1,
        'completionPercent': 100,
      };
      expect(
        collectorTypeStatsAreCurrent(storedVersion: null, statsJson: json),
        isFalse,
      );
      expect(
        collectorTypeStatsAreCurrent(storedVersion: 1, statsJson: json),
        isFalse,
      );
    });

    test('false when required v2 keys are missing', () {
      expect(
        collectorTypeStatsAreCurrent(
          storedVersion: kCollectorTypeStatsVersion,
          statsJson: {
            'completedSeriesCount': 1,
            'masterCompleteSeriesCount': 1,
            'completionPercent': 100,
          },
        ),
        isFalse,
      );
    });

    test('true when version and required keys match', () {
      expect(
        collectorTypeStatsAreCurrent(
          storedVersion: kCollectorTypeStatsVersion,
          statsJson: {
            'completedSeriesCount': 1,
            'masterCompleteSeriesCount': 1,
            'masterEligibleSeriesCount': 1,
            'completionPercent': 100,
          },
        ),
        isTrue,
      );
    });
  });

  group('resolveCollectorTypeDisplayStats', () {
    test('uses frozen stats when schema is current', () {
      final frozen = _stats(
        completedSeriesCount: 2,
        masterCompleteSeriesCount: 1,
        masterEligibleSeriesCount: 1,
        completionPercent: 88,
      );
      final identity = CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.completionist,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'sig',
        stats: frozen,
        reasonKey: CollectorTypeReasonKey.deepCompletion,
      );
      final memory = CollectionMemoryData(
        collectorTypeStatsJson:
            '{"completedSeriesCount":2,"masterCompleteSeriesCount":1,'
            '"masterEligibleSeriesCount":1,"completionPercent":88}',
        collectorTypeStatsVersion: kCollectorTypeStatsVersion,
      );
      final display = resolveCollectorTypeDisplayStats(
        storedIdentity: identity,
        memory: memory,
        snapshot: CollectionSnapshot.emptyTest(),
        profile: interpretShelf(CollectionSnapshot.emptyTest()),
      );
      expect(display.completionPercent, 88);
      expect(display.completedSeriesCount, 2);
      expect(identical(display, frozen), isTrue);
    });

    test('live-derives when version is outdated without rewriting identity', () {
      final series = testShelfSeries(
        id: 'm',
        figures: const [
          ShelfFigure(
            id: 'r0',
            seriesId: 'm',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'sec',
            seriesId: 'm',
            name: 'S',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'r0': TrackedFigure(
            figureId: 'r0',
            state: FigureCollectionState.owned,
          ),
          'sec': TrackedFigure(
            figureId: 'sec',
            state: FigureCollectionState.owned,
          ),
        },
      );
      final profile = interpretShelf(snap);
      final frozen = _stats(completionPercent: 40);
      final identity = CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.hunter,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'sig',
        stats: frozen,
        reasonKey: CollectorTypeReasonKey.manySecrets,
      );
      final memory = CollectionMemoryData(
        collectorTypeStatsJson: '{"completionPercent":40,"trackedSeries":1}',
        collectorTypeStatsVersion: 1,
      );

      final display = resolveCollectorTypeDisplayStats(
        storedIdentity: identity,
        memory: memory,
        snapshot: snap,
        profile: profile,
      );

      expect(display.completedSeriesCount, 1);
      expect(display.masterCompleteSeriesCount, 1);
      expect(display.masterEligibleSeriesCount, 1);
      expect(display.completionPercent, 100);
      expect(identity.archetypeId, CollectorTypeArchetypeId.hunter);
      expect(identity.stats.completionPercent, 40);
    });
  });

  group('needsReveal + stats schema', () {
    test('outdated stats schema marks needsReveal', () {
      final live = CollectorTypeResolution(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        score: 0,
        confidence: 0.2,
        reasonKey: CollectorTypeReasonKey.stillUnfolding,
        signatureHash: 'same',
        stats: _stats(),
        scores: const {},
        reasons: const {},
      );
      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: 'same',
          persistedResolverVersion: kCollectorTypeResolverVersion,
          liveCandidate: live,
          persistedStatsAreCurrent: false,
        ),
        isTrue,
      );
      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: 'same',
          persistedResolverVersion: kCollectorTypeResolverVersion,
          liveCandidate: live,
          persistedStatsAreCurrent: true,
        ),
        isFalse,
      );
    });
  });
}
