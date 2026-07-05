import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/master_complete_transition.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  group('newlyMasterCompleteSeries', () {
    test('returns empty when nothing changed', () {
      final snap = CollectionSnapshot.emptyTest();
      expect(newlyMasterCompleteSeries(snap, snap), isEmpty);
    });

    test('detects master transition for existing shelf row', () {
      final series = testShelfSeries(
        id: 's1',
        figures: [
          const ShelfFigure(
            id: 'r1',
            seriesId: 's1',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'x1',
            seriesId: 's1',
            name: 'S',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final previous = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'r1': const TrackedFigure(
            figureId: 'r1',
            state: FigureCollectionState.owned,
          ),
        },
      );
      final next = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'r1': const TrackedFigure(
            figureId: 'r1',
            state: FigureCollectionState.owned,
          ),
          'x1': const TrackedFigure(
            figureId: 'x1',
            state: FigureCollectionState.owned,
          ),
        },
      );

      expect(
        seriesNewlyMasterComplete(
          series: series,
          previous: previous,
          next: next,
        ),
        isTrue,
      );
    });
  });
}
