import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfSeries _seriesWithSecrets({
  required String id,
  required int regularCount,
  required int secretCount,
}) {
  final figures = <ShelfFigure>[
    for (var i = 0; i < regularCount; i++)
      ShelfFigure(
        id: '${id}_reg_$i',
        seriesId: id,
        name: 'R $i',
        rarity: 'Regular',
        isSecret: false,
      ),
    for (var i = 0; i < secretCount; i++)
      ShelfFigure(
        id: '${id}_sec_$i',
        seriesId: id,
        name: 'S $i',
        rarity: 'Secret',
        isSecret: true,
      ),
  ];
  return testShelfSeries(id: id, name: 'Series $id', figures: figures);
}

Map<String, TrackedFigure> _ownedIds(List<String> ids) {
  return {
    for (final id in ids)
      id: TrackedFigure(figureId: id, state: FigureCollectionState.owned),
  };
}

void main() {
  group('resolveSeriesCompletion', () {
    test('regular complete with secret missing is completed not master', () {
      final series = _seriesWithSecrets(id: 'a', regularCount: 12, secretCount: 1);
      final states = _ownedIds([
        for (var i = 0; i < 12; i++) 'a_reg_$i',
      ]);
      final r = resolveSeriesCompletion(series, states);
      expect(r.isCompleted, isTrue);
      expect(r.isMasterComplete, isFalse);
      expect(r.progressRatio, 1.0);
    });

    test('all regular and secret owned is master complete', () {
      final series = _seriesWithSecrets(id: 'b', regularCount: 2, secretCount: 1);
      final states = _ownedIds(['b_reg_0', 'b_reg_1', 'b_sec_0']);
      final r = resolveSeriesCompletion(series, states);
      expect(r.isCompleted, isTrue);
      expect(r.isMasterComplete, isTrue);
    });

    test('no secret series completes when all regular owned', () {
      final series = _seriesWithSecrets(id: 'c', regularCount: 3, secretCount: 0);
      final states = _ownedIds(['c_reg_0', 'c_reg_1', 'c_reg_2']);
      final r = resolveSeriesCompletion(series, states);
      expect(r.isCompleted, isTrue);
      expect(r.isMasterComplete, isFalse);
    });

    test('in progress uses regular denominator when secrets exist', () {
      final series = _seriesWithSecrets(id: 'd', regularCount: 4, secretCount: 1);
      final states = _ownedIds(['d_reg_0', 'd_reg_1']);
      final r = resolveSeriesCompletion(series, states);
      expect(r.isCompleted, isFalse);
      expect(r.progressRatio, 0.5);
    });

    test('secret owned but regular missing stays in progress', () {
      final series = _seriesWithSecrets(id: 'e', regularCount: 2, secretCount: 1);
      final states = _ownedIds(['e_sec_0']);
      final r = resolveSeriesCompletion(series, states);
      expect(r.isCompleted, isFalse);
    });
  });

  group('countShelfCompletionTiers', () {
    test('counts completed and master across shelf', () {
      final regularOnly = _seriesWithSecrets(id: 'done', regularCount: 2, secretCount: 0);
      final master = _seriesWithSecrets(id: 'master', regularCount: 1, secretCount: 1);
      final open = _seriesWithSecrets(id: 'open', regularCount: 2, secretCount: 1);
      final snap = CollectionSnapshot(
        shelfSeries: [regularOnly, master, open],
        figureStates: {
          ..._ownedIds(['done_reg_0', 'done_reg_1']),
          ..._ownedIds(['master_reg_0', 'master_sec_0']),
          ..._ownedIds(['open_reg_0']),
        },
      );
      final (completed, masterCount) = countShelfCompletionTiers(snap);
      expect(completed, 2);
      expect(masterCount, 1);
    });
  });
}
