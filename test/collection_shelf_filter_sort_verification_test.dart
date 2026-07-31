import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filter_matching.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';
import 'helpers/collection_shelf_logic_fixtures.dart';

/// Gap-fill verification for Filter + Sort composition and boundary semantics.
///
/// Complements the broader suites in `collection_shelf_filter_sort_logic_test`,
/// `collection_shelf_browse_test`, and the Filters sheet widget tests.
void main() {
  group('Progress filter vs rail partition', () {
    test(
      'zero-owned rows fail Progress inProgress but stay in In Progress bucket',
      () {
        final series = [
          testShelfSeries(
            id: 'zero',
            name: 'Zero Owned',
            figures: [
              const ShelfFigure(
                id: 'z0',
                seriesId: 'zero',
                name: 'Fig',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 'started',
            name: 'Started',
            figures: [
              const ShelfFigure(
                id: 's0',
                seriesId: 'started',
                name: 'Fig',
                rarity: 'Regular',
                isSecret: false,
              ),
              const ShelfFigure(
                id: 's1',
                seriesId: 'started',
                name: 'Fig 2',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ];
        final states = <String, TrackedFigure>{
          's0': const TrackedFigure(
            figureId: 's0',
            state: FigureCollectionState.owned,
          ),
        };

        final filtered = applyCollectionShelfFilters(
          series,
          states,
          const CollectionShelfFilters(
            progress: CollectionShelfProgressFilter.inProgress,
          ),
        );
        expect(filtered.map((s) => s.id), ['started']);

        final (inProgress, completed) = partitionShelfSeries(series, states);
        expect(inProgress.map((s) => s.id).toList(), ['zero', 'started']);
        expect(completed, isEmpty);
      },
    );

    test(
      'Master Complete is in Completed bucket but Progress completed excludes it',
      () {
        final m = CollectionShelfLogicFixtures.build();
        final series = m.shelfSeries
            .where(
              (s) => s.id == 'delta_secret_owned' || s.id == 'golf_complete',
            )
            .toList();
        final states = m.figureStates;

        final completedFilter = applyCollectionShelfFilters(
          series,
          states,
          const CollectionShelfFilters(
            progress: CollectionShelfProgressFilter.completed,
          ),
          catalog: m.catalogLookup,
        );
        expect(completedFilter.map((s) => s.id), ['golf_complete']);

        final masterFilter = applyCollectionShelfFilters(
          series,
          states,
          const CollectionShelfFilters(
            progress: CollectionShelfProgressFilter.masterComplete,
          ),
          catalog: m.catalogLookup,
        );
        expect(masterFilter.map((s) => s.id), ['delta_secret_owned']);

        final (_, completedBucket) = partitionShelfSeries(series, states);
        expect(completedBucket.map((s) => s.id).toSet(), {
          'delta_secret_owned',
          'golf_complete',
        });
      },
    );
  });

  group('Alphabetical exact semantics', () {
    test(
      'does not trim leading/trailing whitespace; case-insensitive tie-break by id',
      () {
        final padded = testShelfSeries(id: 'pad', name: '  Bravo');
        final plain = testShelfSeries(id: 'plain', name: 'bravo');
        final alpha = testShelfSeries(id: 'alpha', name: 'Alpha');
        final source = [padded, plain, alpha];
        final sorted = sortShelfSeriesForDisplay(
          source,
          CollectionShelfSort.alphabetical,
          const {},
        );
        // Lowercase: "  bravo" < "alpha" < "bravo" by code-unit order of space.
        expect(sorted.map((s) => s.id).toList(), ['pad', 'alpha', 'plain']);
        expect(identical(sorted, source), isFalse);
        expect(source.map((s) => s.id).toList(), ['pad', 'plain', 'alpha']);
      },
    );
  });

  group('Has Duplicates × every Sort (filter then sort)', () {
    late CollectionShelfLogicMatrix m;

    setUp(() {
      m = CollectionShelfLogicFixtures.build();
    });

    for (final sort in CollectionShelfSort.values) {
      test(
        'hasDuplicates then ${sort.name} never reintroduces excluded rows',
        () {
          const filters = CollectionShelfFilters(hasDuplicates: true);
          final filtered = applyCollectionShelfFilters(
            m.shelfSeries,
            m.figureStates,
            filters,
            catalog: m.catalogLookup,
          );
          expect(filtered, isNotEmpty);
          for (final row in filtered) {
            expect(
              progressForSeries(row, m.figureStates).hasDuplicates,
              isTrue,
              reason: row.id,
            );
          }

          final sorted = sortShelfSeriesForDisplay(
            filtered,
            sort,
            m.figureStates,
            catalog: m.catalogBundle,
          );
          expect(
            sorted.map((s) => s.id).toSet(),
            filtered.map((s) => s.id).toSet(),
          );
          expect(sorted.length, filtered.length);

          // Section boundaries: partition after filter+sort still uses completion.
          final (inProgress, completed) = partitionShelfSeries(
            sorted,
            m.figureStates,
          );
          for (final row in inProgress) {
            expect(isShelfSeriesComplete(row, m.figureStates), isFalse);
          }
          for (final row in completed) {
            expect(isShelfSeriesComplete(row, m.figureStates), isTrue);
          }
        },
      );
    }
  });

  group('Ownership changes recompute immediately', () {
    test('adding a duplicate copy promotes a series into Has Duplicates', () {
      final series = [
        testShelfSeries(
          id: 'solo',
          name: 'Solo',
          figures: [
            const ShelfFigure(
              id: 'f0',
              seriesId: 'solo',
              name: 'Fig',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ];
      var states = <String, TrackedFigure>{
        'f0': const TrackedFigure(
          figureId: 'f0',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };
      const filters = CollectionShelfFilters(hasDuplicates: true);

      expect(applyCollectionShelfFilters(series, states, filters), isEmpty);

      states = {
        'f0': const TrackedFigure(
          figureId: 'f0',
          state: FigureCollectionState.owned,
          ownedQuantity: 2,
        ),
      };
      expect(
        applyCollectionShelfFilters(series, states, filters).single.id,
        'solo',
      );
    });

    test('removing the last owned figure drops Progress inProgress match', () {
      final series = [
        testShelfSeries(
          id: 'row',
          name: 'Row',
          figures: [
            const ShelfFigure(
              id: 'a',
              seriesId: 'row',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
            const ShelfFigure(
              id: 'b',
              seriesId: 'row',
              name: 'B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ];
      var states = <String, TrackedFigure>{
        'a': const TrackedFigure(
          figureId: 'a',
          state: FigureCollectionState.owned,
        ),
      };
      const filters = CollectionShelfFilters(
        progress: CollectionShelfProgressFilter.inProgress,
      );

      expect(applyCollectionShelfFilters(series, states, filters), isNotEmpty);

      states = {};
      expect(applyCollectionShelfFilters(series, states, filters), isEmpty);
    });
  });

  group('Display noise does not affect filter identity', () {
    test(
      'long titles and missing taxonomy still match Has Duplicates by qty',
      () {
        final series = [
          testShelfSeries(
            id: 'long',
            name:
                'Extremely Long Series Title That Must Not Influence Filter Keys',
            brand: '',
            ipName: '',
            taxonomyBrandId: null,
            taxonomyIpId: null,
            catalogTemplateId: null,
            figures: [
              const ShelfFigure(
                id: 'lf0',
                seriesId: 'long',
                name: 'Fig',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ];
        final states = <String, TrackedFigure>{
          'lf0': const TrackedFigure(
            figureId: 'lf0',
            state: FigureCollectionState.owned,
            ownedQuantity: 3,
          ),
        };

        final matched = applyCollectionShelfFilters(
          series,
          states,
          const CollectionShelfFilters(hasDuplicates: true),
        );
        expect(matched.single.id, 'long');
        expect(progressForSeries(series.single, states).duplicateCount, 2);
      },
    );
  });

  group('Persistence asymmetry (product design)', () {
    test('UiPrefs codec persists Sort but never Filters', () {
      const prefs = CollectionShelfUiPrefs(
        sort: CollectionShelfSort.figureCount,
      );
      final encoded = CollectionShelfUiPrefsCodec.encode(prefs);
      expect(encoded, contains('"sort":"figureCount"'));
      expect(encoded, isNot(contains('filters')));
      expect(encoded, isNot(contains('hasDuplicates')));
      expect(encoded, isNot(contains('"progress"')));

      final decoded = CollectionShelfUiPrefsCodec.decode(encoded);
      expect(decoded.sort, CollectionShelfSort.figureCount);
    });

    test('Clear Filters leaves Sort selection untouched at model level', () {
      var filters = const CollectionShelfFilters(
        hasDuplicates: true,
        brandIds: {'popmart'},
      );
      var sort = CollectionShelfSort.alphabetical;
      filters = filters.cleared();
      expect(filters, CollectionShelfFilters.empty);
      expect(sort, CollectionShelfSort.alphabetical);
    });
  });

  group('Section classification after filter+sort', () {
    test('sorting cannot move a series across Completed / In Progress', () {
      final m = CollectionShelfLogicFixtures.build();
      for (final sort in CollectionShelfSort.values) {
        final filtered = applyCollectionShelfFilters(
          m.shelfSeries,
          m.figureStates,
          CollectionShelfFilters.empty,
          catalog: m.catalogLookup,
        );
        final sorted = sortShelfSeriesForDisplay(
          filtered,
          sort,
          m.figureStates,
          catalog: m.catalogBundle,
        );
        final (inProgress, completed) = partitionShelfSeries(
          sorted,
          m.figureStates,
        );
        final before = {
          for (final s in filtered)
            s.id: isShelfSeriesComplete(s, m.figureStates),
        };
        for (final s in inProgress) {
          expect(before[s.id], isFalse, reason: '${sort.name}:${s.id}');
        }
        for (final s in completed) {
          expect(before[s.id], isTrue, reason: '${sort.name}:${s.id}');
        }
      }
    });
  });
}
