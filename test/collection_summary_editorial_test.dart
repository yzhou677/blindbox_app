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
        anyOf(contains('taking shape'), contains('character')),
      );
    });

    test('master stage when master complete series exist', () {
      final series = _seriesWithSecret(id: 'm', name: 'Macaron');
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'm_r0': TrackedFigure(
            figureId: 'm_r0',
            state: FigureCollectionState.owned,
          ),
          'm_s0': TrackedFigure(
            figureId: 'm_s0',
            state: FigureCollectionState.owned,
          ),
        },
      );
      expect(
        CollectionSummaryEditorial.shelfMoodLine(snap),
        anyOf(contains('Master Complete series'), contains('finishing every figure')),
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
      expect(line, 'Macaron is your latest completed series');
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
