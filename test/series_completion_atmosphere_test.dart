import 'package:blindbox_app/features/collection/application/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nearComplete when most figures owned', () {
    final figures = [
      for (var i = 0; i < 7; i++)
        ShelfFigure(
          id: 'f$i',
          seriesId: 'series_test',
          name: 'F$i',
          rarity: 'Regular',
          isSecret: false,
        ),
    ];
    final series = testShelfSeries(figures: figures);
    final states = <String, TrackedFigure>{
      for (var i = 0; i < 6; i++)
        'f$i': TrackedFigure(figureId: 'f$i', state: FigureCollectionState.owned),
    };

    final atm = atmosphereForSeries(series, states);
    expect(atm.nearComplete, isTrue);
    expect(atm.complete, isFalse);
  });

  test('missingSecret when regular complete and chase unowned', () {
    final series = testShelfSeries(
      figures: [
        const ShelfFigure(
          id: 'reg',
          seriesId: 'series_test',
          name: 'Regular',
          rarity: 'Regular',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'sec',
          seriesId: 'series_test',
          name: 'Secret',
          rarity: 'Secret',
          isSecret: true,
        ),
      ],
    );
    final atm = atmosphereForSeries(series, {
      'reg': const TrackedFigure(
        figureId: 'reg',
        state: FigureCollectionState.owned,
      ),
    });
    expect(atm.complete, isTrue);
    expect(atm.missingSecret, isTrue);
    expect(atm.masterComplete, isFalse);
  });

  test('masterComplete when regular and secret owned', () {
    final series = testShelfSeries(
      figures: [
        const ShelfFigure(
          id: 'reg',
          seriesId: 'series_test',
          name: 'Regular',
          rarity: 'Regular',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'sec',
          seriesId: 'series_test',
          name: 'Secret',
          rarity: 'Secret',
          isSecret: true,
        ),
      ],
    );
    final atm = atmosphereForSeries(series, {
      'reg': const TrackedFigure(
        figureId: 'reg',
        state: FigureCollectionState.owned,
      ),
      'sec': const TrackedFigure(
        figureId: 'sec',
        state: FigureCollectionState.owned,
      ),
    });
    expect(atm.masterComplete, isTrue);
    expect(atm.missingSecret, isFalse);
  });

  test('nearComplete with Secrets uses progressRatio not all-figure fill', () {
    final figures = <ShelfFigure>[
      for (var i = 0; i < 7; i++)
        ShelfFigure(
          id: 'r$i',
          seriesId: 'series_test',
          name: 'R$i',
          rarity: 'Regular',
          isSecret: false,
        ),
      const ShelfFigure(
        id: 'sec',
        seriesId: 'series_test',
        name: 'Secret',
        rarity: 'Secret',
        isSecret: true,
      ),
    ];
    final series = testShelfSeries(figures: figures);
    final states = <String, TrackedFigure>{
      for (var i = 0; i < 6; i++)
        'r$i': TrackedFigure(figureId: 'r$i', state: FigureCollectionState.owned),
    };

    final atm = atmosphereForSeries(series, states);
    // 6/7 Regular ⇒ Near; 6/8 all-figure would not be Near.
    expect(atm.nearComplete, isTrue);
    expect(atm.complete, isFalse);
  });
}
