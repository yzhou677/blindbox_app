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

  test('missingSecret when chase unowned', () {
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
    final atm = atmosphereForSeries(series, const {});
    expect(atm.missingSecret, isTrue);
  });

  test('complete when all owned', () {
    final series = testShelfSeries();
    final fid = series.figures.first.id;
    final atm = atmosphereForSeries(series, <String, TrackedFigure>{
      fid: TrackedFigure(figureId: fid, state: FigureCollectionState.owned),
    });
    expect(atm.complete, isTrue);
  });
}
