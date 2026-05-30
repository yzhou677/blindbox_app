import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  test('collector journey is empty when memory has no history', () {
    final summary = buildCollectorJourneySummary(
      memory: const CollectionMemoryData(),
      snapshot: CollectionSnapshot.emptyTest(),
      now: DateTime(2026, 5, 29),
    );

    expect(summary.hasHistory, isFalse);
    expect(summary.ipUniversesExplored, 0);
    expect(summary.seriesExploredOverTime, 0);
    expect(summary.topIps, isEmpty);
    expect(summary.journeyAgeLabel, isNull);
  });

  test('collector journey builds top explored ordering from memory depth', () {
    final snapshot = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(
          id: 's1',
          ipName: 'Smiski',
          taxonomyIpId: 'smiski',
          taxonomyBrandId: 'dreams_inc',
          brand: 'Dreams Inc.',
        ),
      ],
      figureStates: const {},
    );
    final summary = buildCollectorJourneySummary(
      memory: const CollectionMemoryData(
        ipSeriesDepth: {'dora': 3, 'smiski': 8, 'maymei': 3, 'crybaby': 1},
        firstSeriesAddedAtMs: 1716940800000, // 2024-05-29
      ),
      snapshot: snapshot,
      now: DateTime(2026, 5, 29),
    );

    expect(summary.hasHistory, isTrue);
    expect(summary.ipUniversesExplored, 4);
    expect(summary.seriesExploredOverTime, 15);
    expect(summary.topIps.map((entry) => entry.label), [
      'Smiski',
      'Dora',
      'Maymei',
    ]);
    expect(summary.topIps.map((entry) => entry.seriesCount), [8, 3, 3]);
    expect(summary.journeyAgeLabel, '2 years ago');
  });

  test('journey age formatting uses days, months, and years', () {
    expect(
      formatJourneyAgeLabel(
        startedAt: DateTime(2026, 5, 1),
        now: DateTime(2026, 5, 29),
      ),
      '28 days ago',
    );
    expect(
      formatJourneyAgeLabel(
        startedAt: DateTime(2026, 1, 1),
        now: DateTime(2026, 5, 29),
      ),
      '4 months ago',
    );
    expect(
      formatJourneyAgeLabel(
        startedAt: DateTime(2024, 10, 1),
        now: DateTime(2026, 5, 29),
      ),
      '1 year 8 months ago',
    );
  });

  test(
    'suppresses misleading recent journey age when history is substantial',
    () {
      final summary = buildCollectorJourneySummary(
        memory: CollectionMemoryData(
          firstSeriesAddedAtMs: DateTime(2026, 5, 29).millisecondsSinceEpoch,
          ipSeriesDepth: const {
            'smiski': 8,
            'dora': 3,
            'maymei': 3,
            'crybaby': 1,
            'baby_three': 1,
            'nommi': 2,
            'pucky': 1,
            'the_monsters': 1,
          },
        ),
        snapshot: CollectionSnapshot.emptyTest(),
        now: DateTime(2026, 5, 29, 23, 59),
      );

      expect(summary.ipUniversesExplored, 8);
      expect(summary.journeyAgeLabel, isNull);
    },
  );

  test('keeps recent journey age for low historical breadth', () {
    final summary = buildCollectorJourneySummary(
      memory: CollectionMemoryData(
        firstSeriesAddedAtMs: DateTime(2026, 5, 29).millisecondsSinceEpoch,
        ipSeriesDepth: const {'smiski': 1, 'dora': 1},
      ),
      snapshot: CollectionSnapshot.emptyTest(),
      now: DateTime(2026, 5, 29, 23, 59),
    );

    expect(summary.ipUniversesExplored, 2);
    expect(summary.journeyAgeLabel, '0 days ago');
  });
}
