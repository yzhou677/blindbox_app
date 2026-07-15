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
        startedAt: DateTime(2026, 5, 29),
        now: DateTime(2026, 5, 29, 23, 59),
      ),
      'Today',
    );
    expect(
      formatJourneyAgeLabel(
        startedAt: DateTime(2026, 5, 28),
        now: DateTime(2026, 5, 29, 23, 59),
      ),
      'Yesterday',
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
    'keeps recent journey age even with substantial exploration breadth',
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
      expect(summary.journeyAgeLabel, 'Today');
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
    expect(summary.journeyAgeLabel, 'Today');
  });

  group('pickLatestJourneyMemory', () {
    final now = DateTime(2026, 5, 29);

    test('prefers Master Complete when latest completion is still master', () {
      final series = testShelfSeries(
        id: 'petals',
        name: 'SKULLPANDA Petals',
        figures: const [
          ShelfFigure(
            id: 'r0',
            seriesId: 'petals',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'sec',
            seriesId: 'petals',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final states = {
        for (final f in series.figures)
          f.id: TrackedFigure(
            figureId: f.id,
            state: FigureCollectionState.owned,
          ),
      };
      final memory = pickLatestJourneyMemory(
        memory: CollectionMemoryData(
          lastCompletedSeriesId: 'petals',
          lastCompletedAtMs: DateTime(2026, 5, 24).millisecondsSinceEpoch,
          firstSecretOwnedAtMs: DateTime(2026, 4, 1).millisecondsSinceEpoch,
        ),
        snapshot: CollectionSnapshot(
          shelfSeries: [series],
          figureStates: states,
        ),
        now: now,
      );

      expect(memory?.kind, JourneyMemoryKind.masterComplete);
      expect(memory?.seriesName, 'SKULLPANDA Petals');
      expect(memory?.ageLabel, '5 days ago');
    });

    test('falls back to Completed Series when not master', () {
      final series = testShelfSeries(
        id: 'fairy',
        name: 'NOMMI Fairy Tale',
        figures: const [
          ShelfFigure(
            id: 'r0',
            seriesId: 'fairy',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'sec',
            seriesId: 'fairy',
            name: 'Chase',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final states = {
        'r0': TrackedFigure(figureId: 'r0', state: FigureCollectionState.owned),
      };
      final memory = pickLatestJourneyMemory(
        memory: CollectionMemoryData(
          lastCompletedSeriesId: 'fairy',
          lastCompletedAtMs: DateTime(2026, 5, 15).millisecondsSinceEpoch,
          firstSecretOwnedAtMs: DateTime(2026, 4, 1).millisecondsSinceEpoch,
        ),
        snapshot: CollectionSnapshot(
          shelfSeries: [series],
          figureStates: states,
        ),
        now: now,
      );

      expect(memory?.kind, JourneyMemoryKind.completedSeries);
      expect(memory?.seriesName, 'NOMMI Fairy Tale');
      expect(memory?.ageLabel, '14 days ago');
    });

    test('falls back to First Secret when no completion memory', () {
      final memory = pickLatestJourneyMemory(
        memory: CollectionMemoryData(
          firstSecretOwnedAtMs: DateTime(2026, 5, 11).millisecondsSinceEpoch,
        ),
        snapshot: CollectionSnapshot.emptyTest(),
        now: now,
      );

      expect(memory?.kind, JourneyMemoryKind.firstSecret);
      expect(memory?.seriesName, isNull);
      expect(memory?.ageLabel, '18 days ago');
    });

    test('returns null when no memories exist', () {
      expect(
        pickLatestJourneyMemory(
          memory: const CollectionMemoryData(),
          snapshot: CollectionSnapshot.emptyTest(),
          now: now,
        ),
        isNull,
      );
    });
  });
}
