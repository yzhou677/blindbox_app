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

  group('aggregateShelfCompletion', () {
    test('8/8 Regular + 0/1 Secret contributes 100% Regular Completion', () {
      final series = _seriesWithSecrets(id: 'a', regularCount: 8, secretCount: 1);
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedIds([for (var i = 0; i < 8; i++) 'a_reg_$i']),
      );
      final r = resolveSeriesCompletion(series, snap.figureStates);
      expect(r.isCompleted, isTrue);
      expect(r.isMasterComplete, isFalse);
      expect(r.progressRatio, 1.0);

      final a = aggregateShelfCompletion(snap);
      expect(a.regularCompletionPercent, 100);
      expect(a.masterCompleteSeriesCount, 0);
      expect(a.masterEligibleSeriesCount, 1);
      expect(a.masterCompletionPercent, 0);
    });

    test('8/8 Regular + 1/1 Secret is Master Complete at 100%', () {
      final series = _seriesWithSecrets(id: 'b', regularCount: 8, secretCount: 1);
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedIds([
          for (var i = 0; i < 8; i++) 'b_reg_$i',
          'b_sec_0',
        ]),
      );
      final r = resolveSeriesCompletion(series, snap.figureStates);
      expect(r.isCompleted, isTrue);
      expect(r.isMasterComplete, isTrue);

      final a = aggregateShelfCompletion(snap);
      expect(a.regularCompletionPercent, 100);
      expect(a.masterCompleteSeriesCount, 1);
      expect(a.masterEligibleSeriesCount, 1);
      expect(a.masterCompletionPercent, 100);
    });

    test('Master Completion excludes no-Secret series from denominator', () {
      final done = [
        for (var i = 0; i < 3; i++)
          _seriesWithSecrets(id: 'ns$i', regularCount: 1, secretCount: 0),
      ];
      final masters = [
        _seriesWithSecrets(id: 'm0', regularCount: 1, secretCount: 1),
        _seriesWithSecrets(id: 'm1', regularCount: 1, secretCount: 1),
      ];
      final snap = CollectionSnapshot(
        shelfSeries: [...done, ...masters],
        figureStates: {
          ..._ownedIds(['ns0_reg_0', 'ns1_reg_0', 'ns2_reg_0']),
          ..._ownedIds(['m0_reg_0', 'm0_sec_0', 'm1_reg_0', 'm1_sec_0']),
        },
      );
      final a = aggregateShelfCompletion(snap);
      expect(a.completedSeriesCount, 5);
      expect(a.masterEligibleSeriesCount, 2);
      expect(a.masterCompleteSeriesCount, 2);
      expect(a.masterCompletionPercent, 100);
      expect(a.regularCompletionPercent, 100);
    });

    test('Master Completion 50% when one of two eligible is master', () {
      final m0 = _seriesWithSecrets(id: 'm0', regularCount: 1, secretCount: 1);
      final m1 = _seriesWithSecrets(id: 'm1', regularCount: 1, secretCount: 1);
      final snap = CollectionSnapshot(
        shelfSeries: [m0, m1],
        figureStates: {
          ..._ownedIds(['m0_reg_0', 'm0_sec_0']),
          ..._ownedIds(['m1_reg_0']), // complete regular, missing secret
        },
      );
      final a = aggregateShelfCompletion(snap);
      expect(a.masterEligibleSeriesCount, 2);
      expect(a.masterCompleteSeriesCount, 1);
      expect(a.masterCompletionPercent, 50);
      expect(a.regularCompletionPercent, 100);
    });

    test('no Secret-bearing series: eligible 0, no divide-by-zero', () {
      final series = _seriesWithSecrets(id: 'c', regularCount: 2, secretCount: 0);
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedIds(['c_reg_0', 'c_reg_1']),
      );
      final a = aggregateShelfCompletion(snap);
      expect(a.masterEligibleSeriesCount, 0);
      expect(a.masterCompleteSeriesCount, 0);
      expect(a.masterCompletionRatio, 0);
      expect(a.masterCompletionPercent, 0);
      expect(a.regularCompletionPercent, 100);
    });

    test('empty shelf is safe', () {
      final a = aggregateShelfCompletion(CollectionSnapshot.emptyTest());
      expect(a.regularCompletionPercent, 0);
      expect(a.masterEligibleSeriesCount, 0);
      expect(a.masterCompletionPercent, 0);
      expect(a.completedSeriesCount, 0);
    });

    test('secret-only series follows resolveSeriesCompletion', () {
      final series = _seriesWithSecrets(id: 'sec', regularCount: 0, secretCount: 2);
      final partial = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedIds(['sec_sec_0']),
      );
      final rPartial =
          resolveSeriesCompletion(series, partial.figureStates);
      expect(rPartial.isCompleted, isFalse);
      expect(rPartial.isMasterComplete, isFalse);
      expect(rPartial.progressRatio, 0.5);

      final full = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedIds(['sec_sec_0', 'sec_sec_1']),
      );
      final rFull = resolveSeriesCompletion(series, full.figureStates);
      expect(rFull.isCompleted, isTrue);
      expect(rFull.isMasterComplete, isTrue);
      expect(aggregateShelfCompletion(full).masterCompletionPercent, 100);
    });

    test('Near Complete with Secrets matches progressRatio definition', () {
      // 6/7 Regular, 0/1 Secret → progressRatio 6/7 ≈ 0.857 Near;
      // all-figure fill would be 6/8 = 0.75 (not Near).
      final series = _seriesWithSecrets(id: 'n', regularCount: 7, secretCount: 1);
      final states = _ownedIds([for (var i = 0; i < 6; i++) 'n_reg_$i']);
      final r = resolveSeriesCompletion(series, states);
      expect(r.isCompleted, isFalse);
      expect(r.isNearComplete, isTrue);
      expect(r.progressRatio, closeTo(6 / 7, 0.001));
    });
  });
}

