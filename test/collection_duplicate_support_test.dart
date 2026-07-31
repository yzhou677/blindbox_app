import 'dart:convert';

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  group('TrackedFigure ownedQuantity', () {
    test('legacy owned record without quantity → quantity 1', () {
      const tracked = TrackedFigure(
        figureId: 'f1',
        state: FigureCollectionState.owned,
      );
      expect(tracked.ownedQuantity, 1);
      expect(tracked.duplicateCount, 0);
    });

    test('legacy unowned / wishlist without quantity → quantity 0', () {
      const missing = TrackedFigure(
        figureId: 'f1',
        state: FigureCollectionState.none,
      );
      const wish = TrackedFigure(
        figureId: 'f1',
        state: FigureCollectionState.wishlist,
      );
      expect(missing.ownedQuantity, 0);
      expect(wish.ownedQuantity, 0);
      expect(missing.duplicateCount, 0);
    });

    test('quantity cannot become negative via normalize', () {
      expect(
        TrackedFigure.normalizeOwnedQuantity(FigureCollectionState.owned, -3),
        1,
      );
      expect(
        TrackedFigure.normalizeOwnedQuantity(FigureCollectionState.owned, 0),
        1,
      );
      expect(
        TrackedFigure.normalizeOwnedQuantity(FigureCollectionState.none, -1),
        0,
      );
    });

    test('quantity 1 → duplicate count 0', () {
      const t = TrackedFigure(
        figureId: 'f1',
        state: FigureCollectionState.owned,
        ownedQuantity: 1,
      );
      expect(t.duplicateCount, 0);
      expect(t.hasDuplicates, isFalse);
    });

    test('quantity 2 → duplicate count 1', () {
      const t = TrackedFigure(
        figureId: 'f1',
        state: FigureCollectionState.owned,
        ownedQuantity: 2,
      );
      expect(t.duplicateCount, 1);
      expect(t.hasDuplicates, isTrue);
    });

    test('quantity 4 → duplicate count 3', () {
      const t = TrackedFigure(
        figureId: 'f1',
        state: FigureCollectionState.owned,
        ownedQuantity: 4,
      );
      expect(t.duplicateCount, 3);
    });
  });

  group('series duplicate aggregation', () {
    test('sums extras across figures', () {
      final series = testShelfSeries(
        figures: const [
          ShelfFigure(
            id: 'a',
            seriesId: 'series_test',
            name: 'A',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'b',
            seriesId: 'series_test',
            name: 'B',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'c',
            seriesId: 'series_test',
            name: 'C',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
      final states = <String, TrackedFigure>{
        'a': const TrackedFigure(
          figureId: 'a',
          state: FigureCollectionState.owned,
          ownedQuantity: 2,
        ),
        'b': const TrackedFigure(
          figureId: 'b',
          state: FigureCollectionState.owned,
          ownedQuantity: 3,
        ),
        'c': const TrackedFigure(
          figureId: 'c',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };
      expect(seriesDuplicateCount(series, states), 3);
      final progress = progressForSeries(series, states);
      expect(progress.owned, 3);
      expect(progress.duplicateCount, 3);
    });
  });

  group('completion ignores duplicate copies', () {
    test('duplicates do not affect completion percentage or unique owned', () {
      final series = testShelfSeries(
        figures: [
          for (var i = 0; i < 12; i++)
            ShelfFigure(
              id: 'fig_$i',
              seriesId: 'series_test',
              name: 'Fig $i',
              rarity: i == 11 ? 'Secret' : 'Regular',
              isSecret: i == 11,
            ),
        ],
      );
      // 8 unique owned (figs 0-7), with extras on 0 and 1 → qty total 11, dups 3
      final states = <String, TrackedFigure>{
        for (var i = 0; i < 8; i++)
          'fig_$i': TrackedFigure(
            figureId: 'fig_$i',
            state: FigureCollectionState.owned,
            ownedQuantity: i == 0
                ? 2
                : i == 1
                ? 4
                : 1,
          ),
      };
      final progress = progressForSeries(series, states);
      expect(progress.owned, 8);
      expect(progress.duplicateCount, 1 + 3);
      final resolution = resolveSeriesCompletion(series, states);
      expect(resolution.regularOwnedCount, 8);
      expect(resolution.secretOwnedCount, 0);
      expect(resolution.isCompleted, isFalse);
      expect(resolution.isMasterComplete, isFalse);
      // Regular slots = 11; owned regulars = 8
      expect(resolution.progressNumerator, 8);
      expect(resolution.progressDenominator, 11);
    });

    test('Master Complete still requires unique secret ownership', () {
      final series = testShelfSeries(
        figures: const [
          ShelfFigure(
            id: 'r1',
            seriesId: 'series_test',
            name: 'R1',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 's1',
            seriesId: 'series_test',
            name: 'S1',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final states = <String, TrackedFigure>{
        'r1': const TrackedFigure(
          figureId: 'r1',
          state: FigureCollectionState.owned,
          ownedQuantity: 5,
        ),
        's1': const TrackedFigure(
          figureId: 's1',
          state: FigureCollectionState.owned,
          ownedQuantity: 3,
        ),
      };
      final resolution = resolveSeriesCompletion(series, states);
      expect(resolution.isCompleted, isTrue);
      expect(resolution.isMasterComplete, isTrue);
      expect(progressForSeries(series, states).owned, 2);
      expect(progressForSeries(series, states).duplicateCount, 4 + 2);
    });
  });

  group('Has Duplicates filter', () {
    test('includes matching series and excludes single-copy series', () {
      final withDups = testShelfSeries(
        id: 'with_dups',
        figures: const [
          ShelfFigure(
            id: 'd1',
            seriesId: 'with_dups',
            name: 'D1',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
      final single = testShelfSeries(
        id: 'single',
        figures: const [
          ShelfFigure(
            id: 's1',
            seriesId: 'single',
            name: 'S1',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
      final states = <String, TrackedFigure>{
        'd1': const TrackedFigure(
          figureId: 'd1',
          state: FigureCollectionState.owned,
          ownedQuantity: 2,
        ),
        's1': const TrackedFigure(
          figureId: 's1',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };
      final filtered = shelfSeriesVisibleForDuplicatesFilter(
        [withDups, single],
        states,
        hasDuplicatesOnly: true,
      );
      expect(filtered.map((s) => s.id), ['with_dups']);
      final all = shelfSeriesVisibleForDuplicatesFilter(
        [withDups, single],
        states,
        hasDuplicatesOnly: false,
      );
      expect(all, hasLength(2));
    });
  });

  group('codec round-trip + legacy decode', () {
    test('ownedQuantity round-trips', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            figures: const [
              ShelfFigure(
                id: 'fig-1',
                seriesId: 'series_test',
                name: 'One',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ],
        figureStates: {
          'fig-1': const TrackedFigure(
            figureId: 'fig-1',
            state: FigureCollectionState.owned,
            ownedQuantity: 3,
            updatedAtMicros: 99,
          ),
        },
      );
      final back = CollectionSnapshotCodec.tryDecode(
        CollectionSnapshotCodec.encode(snap),
      );
      expect(back, isNotNull);
      expect(back!.figureStates['fig-1']?.ownedQuantity, 3);
      expect(back.figureStates['fig-1']?.duplicateCount, 2);
      expect(CollectionSnapshotCodec.encode(snap), contains('"ownedQuantity":3'));
    });

    test('legacy owned without ownedQuantity decodes as 1', () {
      final raw = jsonEncode({
        'v': 3,
        'shelfSeries': [
          {
            'id': 's1',
            'name': 'N',
            'brand': 'B',
            'ipName': 'I',
            'shelfAccentArgb': 0xFF112233,
            'figures': [
              {
                'id': 'fig-1',
                'seriesId': 's1',
                'name': 'One',
                'rarity': 'Regular',
                'isSecret': false,
              },
            ],
          },
        ],
        'figureStates': {
          'fig-1': {'state': 'owned', 'updatedAtMicros': 1},
        },
        'seriesWishlist': const [],
      });
      final back = CollectionSnapshotCodec.tryDecode(raw);
      expect(back!.figureStates['fig-1']?.ownedQuantity, 1);
    });

    test('invalid ownedQuantity values are sanitized', () {
      final raw = jsonEncode({
        'v': 3,
        'shelfSeries': const [],
        'figureStates': {
          'a': {'state': 'owned', 'ownedQuantity': -2},
          'b': {'state': 'owned', 'ownedQuantity': 'nope'},
          'c': {'state': 'owned', 'ownedQuantity': 2.9},
          'd': {'state': 'wishlist', 'ownedQuantity': 9},
        },
        'seriesWishlist': const [],
      });
      final back = CollectionSnapshotCodec.tryDecode(raw)!;
      expect(back.figureStates['a']?.ownedQuantity, 1);
      expect(back.figureStates['b']?.ownedQuantity, 1);
      expect(back.figureStates['c']?.ownedQuantity, 2);
      expect(back.figureStates['d']?.ownedQuantity, 0);
    });
  });

  group('notifier quantity invariants', () {
    ProviderContainer containerWithFigure() {
      CollectionAppBootstrap.prime(
        CollectionSnapshot(
          shelfSeries: [
            testShelfSeries(
              figures: const [
                ShelfFigure(
                  id: 'fig_q',
                  seriesId: 'series_test',
                  name: 'Qty',
                  rarity: 'Regular',
                  isSecret: false,
                ),
              ],
            ),
          ],
          figureStates: const {},
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(collectionNotifierProvider);
      return container;
    }

    test('quantity changes preserve ownership/wishlist invariants', () {
      final container = containerWithFigure();
      final n = container.read(collectionNotifierProvider.notifier);

      n.setFigureOwnedQuantity('fig_q', 2);
      var t = container.read(collectionNotifierProvider).trackedOrDefault('fig_q');
      expect(t.state, FigureCollectionState.owned);
      expect(t.ownedQuantity, 2);

      n.adjustFigureOwnedQuantity('fig_q', 1);
      t = container.read(collectionNotifierProvider).trackedOrDefault('fig_q');
      expect(t.ownedQuantity, 3);

      n.setFigureOwnedQuantity('fig_q', 0);
      t = container.read(collectionNotifierProvider).trackedOrDefault('fig_q');
      expect(t.state, FigureCollectionState.none);
      expect(t.ownedQuantity, 0);

      n.setFigureWishlisted('fig_q', true);
      t = container.read(collectionNotifierProvider).trackedOrDefault('fig_q');
      expect(t.wishlist, isTrue);
      expect(t.ownedQuantity, 0);

      n.setFigureOwnedQuantity('fig_q', 1);
      t = container.read(collectionNotifierProvider).trackedOrDefault('fig_q');
      expect(t.owned, isTrue);
      expect(t.ownedQuantity, 1);

      n.setFigureOwnedQuantity('fig_q', -5);
      t = container.read(collectionNotifierProvider).trackedOrDefault('fig_q');
      expect(t.state, FigureCollectionState.none);

      n.cycleFigure('fig_q'); // wishlist
      n.cycleFigure('fig_q'); // owned qty 1
      t = container.read(collectionNotifierProvider).trackedOrDefault('fig_q');
      expect(t.ownedQuantity, 1);
    });
  });
}
