import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/presentation/collection_memory_editorial.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfSeries _seriesWithSecret({required String id, required String name}) {
  return testShelfSeries(
    id: id,
    name: name,
    figures: [
      ShelfFigure(
        id: '${id}_r0',
        seriesId: id,
        name: 'Regular',
        rarity: 'Regular',
        isSecret: false,
      ),
      ShelfFigure(
        id: '${id}_s0',
        seriesId: id,
        name: 'Secret',
        rarity: 'Secret',
        isSecret: true,
      ),
    ],
  );
}

CollectionSnapshot _snapWithMasterCompleteCount(int count) {
  final series = List.generate(
    count,
    (i) => _seriesWithSecret(id: 'm$i', name: 'Series $i'),
  );
  final states = <String, TrackedFigure>{};
  for (final s in series) {
    for (final f in s.figures) {
      states[f.id] = TrackedFigure(
        figureId: f.id,
        state: FigureCollectionState.owned,
      );
    }
  }
  return CollectionSnapshot(shelfSeries: series, figureStates: states);
}

void main() {
  group('CollectionSummaryEditorial', () {
    test('beginning stage on empty shelf', () {
      const snap = CollectionSnapshot(shelfSeries: [], figureStates: {});
      expect(
        CollectionSummaryEditorial.shelfMoodLine(snap),
        anyOf(contains('getting started'), contains('first lineup')),
      );
    });

    test('growing stage with figures but no completed series', () {
      final series = testShelfSeries(
        figures: [
          const ShelfFigure(
            id: 'grow_r0',
            seriesId: 'series_test',
            name: 'A',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'grow_r1',
            seriesId: 'series_test',
            name: 'B',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'grow_r0': TrackedFigure(
            figureId: 'grow_r0',
            state: FigureCollectionState.owned,
          ),
        },
      );
      expect(
        CollectionSummaryEditorial.shelfMoodLine(snap),
        anyOf(contains('in-progress'), contains('recorded')),
      );
    });

    test('master stage when master complete series exist', () {
      final snap = _snapWithMasterCompleteCount(1);
      expect(
        CollectionSummaryEditorial.shelfMoodLine(snap),
        'Your collection now includes a Master Complete series.',
      );
    });

    test('master stage uses multiple wording for two series', () {
      final snap = _snapWithMasterCompleteCount(2);
      expect(
        CollectionSummaryEditorial.shelfMoodLine(snap),
        'Your collection now includes multiple Master Complete series.',
      );
    });

    test('master stage uses explicit count for three or more', () {
      final snap = _snapWithMasterCompleteCount(8);
      expect(
        CollectionSummaryEditorial.shelfMoodLine(snap),
        'Your collection now includes 8 Master Complete series.',
      );
    });
  });

  group('CollectionMemoryEditorial recent completion', () {
    test('regular complete uses completed wording', () {
      final series = _seriesWithSecret(id: 'a', name: 'Macaron');
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'a_r0': TrackedFigure(
            figureId: 'a_r0',
            state: FigureCollectionState.owned,
          ),
        },
      );
      final line = CollectionMemoryEditorial.whisperForMoment(
        const CollectionMemoryMoment(
          kind: CollectionMemoryMomentKind.recentlyCompletedLineup,
          seriesId: 'a',
          seriesName: 'Macaron',
        ),
        snap: snap,
      );
      expect(line, 'Macaron is your latest Complete series');
    });

    test('master complete uses master wording', () {
      final series = _seriesWithSecret(id: 'b', name: 'Macaron');
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'b_r0': TrackedFigure(
            figureId: 'b_r0',
            state: FigureCollectionState.owned,
          ),
          'b_s0': TrackedFigure(
            figureId: 'b_s0',
            state: FigureCollectionState.owned,
          ),
        },
      );
      final line = CollectionMemoryEditorial.whisperForMoment(
        const CollectionMemoryMoment(
          kind: CollectionMemoryMomentKind.recentlyCompletedLineup,
          seriesId: 'b',
          seriesName: 'Macaron',
        ),
        snap: snap,
      );
      expect(line, 'Macaron is your latest Master Complete series');
    });
  });
}
