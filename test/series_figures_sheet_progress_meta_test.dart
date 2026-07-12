import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfSeries _series({
  required int regular,
  required int secrets,
}) {
  return testShelfSeries(
    id: 's',
    name: 'Series',
    figures: [
      for (var i = 0; i < regular; i++)
        ShelfFigure(
          id: 'r$i',
          seriesId: 's',
          name: 'R$i',
          rarity: 'Regular',
          isSecret: false,
        ),
      for (var i = 0; i < secrets; i++)
        ShelfFigure(
          id: 'sec$i',
          seriesId: 's',
          name: 'S$i',
          rarity: 'Secret',
          isSecret: true,
        ),
    ],
  );
}

Map<String, TrackedFigure> _own(List<String> ids) => {
      for (final id in ids)
        id: TrackedFigure(figureId: id, state: FigureCollectionState.owned),
    };

void main() {
  group('seriesFiguresSheetProgressMeta', () {
    test('regular-only series shows Regular line only', () {
      final series = _series(regular: 3, secrets: 0);
      final resolution = resolveSeriesCompletion(series, _own(['r0', 'r1']));
      expect(
        CollectionProgressVoice.seriesFiguresSheetProgressMeta(resolution),
        'Regular Figures 2 of 3 Collected',
      );
    });

    test('incomplete regular with missing secret', () {
      final series = _series(regular: 8, secrets: 1);
      final owned = [for (var i = 0; i < 8; i++) 'r$i'];
      final resolution = resolveSeriesCompletion(series, _own(owned));
      expect(
        CollectionProgressVoice.seriesFiguresSheetProgressMeta(resolution),
        'Regular Figures 8 of 8 Collected\n'
        'Secret Figures 0 of 1 Collected',
      );
    });

    test('master complete shows both lines full', () {
      final series = _series(regular: 8, secrets: 1);
      final owned = [
        for (var i = 0; i < 8; i++) 'r$i',
        'sec0',
      ];
      final resolution = resolveSeriesCompletion(series, _own(owned));
      expect(resolution.isMasterComplete, isTrue);
      expect(
        CollectionProgressVoice.seriesFiguresSheetProgressMeta(resolution),
        'Regular Figures 8 of 8 Collected\n'
        'Secret Figures 1 of 1 Collected',
      );
    });

    test('multiple secrets track independently', () {
      final series = _series(regular: 2, secrets: 2);
      final resolution =
          resolveSeriesCompletion(series, _own(['r0', 'r1', 'sec0']));
      expect(
        CollectionProgressVoice.seriesFiguresSheetProgressMeta(resolution),
        'Regular Figures 2 of 2 Collected\n'
        'Secret Figures 1 of 2 Collected',
      );
    });

    test('never emits combined X of Y Figures', () {
      final series = _series(regular: 8, secrets: 1);
      final resolution = resolveSeriesCompletion(
        series,
        _own([for (var i = 0; i < 8; i++) 'r$i']),
      );
      final meta =
          CollectionProgressVoice.seriesFiguresSheetProgressMeta(resolution)!;
      expect(meta.contains('of 9'), isFalse);
      expect(meta.contains('Figures 8 of 9'), isFalse);
    });
  });
}
