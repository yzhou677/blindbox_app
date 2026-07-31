import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_facet_collapse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filter_matching.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_filters_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _GroupsTestCollectionNotifier extends CollectionNotifier {
  _GroupsTestCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}
void main() {
  group('normalizeCollectionShelfFilters', () {
    test('keeps Secret Owned and clears Missing when both are set', () {
      final normalized = normalizeCollectionShelfFilters(
        const CollectionShelfFilters(secretOwned: true, secretMissing: true),
      );
      expect(normalized.secretOwned, isTrue);
      expect(normalized.secretMissing, isFalse);
    });

    test('collapses multi brand and IP ids to the first value', () {
      final normalized = normalizeCollectionShelfFilters(
        CollectionShelfFilters(
          brandIds: {'popmart', 'toptoy'},
          ipIds: {'labubu', 'hirono'},
        ),
      );
      expect(normalized.brandIds, {'popmart'});
      expect(normalized.ipIds, {'labubu'});
      expect(normalized.activeCount, 2);
    });

    test('All Brand/IP state does not count as active', () {
      expect(CollectionShelfFilters.empty.activeCount, 0);
      expect(CollectionShelfFilters.empty.hasActive, isFalse);
    });
  });

  group('Progress mutual exclusion', () {
    test('selecting another Progress replaces the previous', () {
      var f = CollectionShelfFilters.empty.toggleProgress(
        CollectionShelfProgressFilter.inProgress,
      );
      f = f.toggleProgress(CollectionShelfProgressFilter.completed);
      expect(f.progress, CollectionShelfProgressFilter.completed);
    });

    test('tapping selected Progress clears it', () {
      final f = CollectionShelfFilters.empty
          .toggleProgress(CollectionShelfProgressFilter.masterComplete)
          .toggleProgress(CollectionShelfProgressFilter.masterComplete);
      expect(f.progress, isNull);
    });

    test('Completed matching includes Master; Master does not include regular Completed',
        () {
      final master = testShelfSeries(
        id: 'm',
        figures: [
          const ShelfFigure(
            id: 'r1',
            seriesId: 'm',
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 's1',
            seriesId: 'm',
            name: 'S',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final regular = testShelfSeries(
        id: 'c',
        figures: [
          const ShelfFigure(
            id: 'cr1',
            seriesId: 'c',
            name: 'R1',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'cr2',
            seriesId: 'c',
            name: 'R2',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'cs1',
            seriesId: 'c',
            name: 'S',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );
      final masterStates = {
        'r1': const TrackedFigure(
          figureId: 'r1',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
        's1': const TrackedFigure(
          figureId: 's1',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };
      final regularStates = {
        'cr1': const TrackedFigure(
          figureId: 'cr1',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
        'cr2': const TrackedFigure(
          figureId: 'cr2',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };

      expect(
        shelfSeriesMatchesProgressFilter(
          master,
          masterStates,
          CollectionShelfProgressFilter.completed,
        ),
        isTrue,
      );
      expect(
        shelfSeriesMatchesProgressFilter(
          master,
          masterStates,
          CollectionShelfProgressFilter.masterComplete,
        ),
        isTrue,
      );
      expect(
        shelfSeriesMatchesProgressFilter(
          regular,
          regularStates,
          CollectionShelfProgressFilter.completed,
        ),
        isTrue,
      );
      expect(
        shelfSeriesMatchesProgressFilter(
          regular,
          regularStates,
          CollectionShelfProgressFilter.masterComplete,
        ),
        isFalse,
      );
    });
  });

  group('Secret Status mutual exclusion', () {
    test('selecting Secret Missing clears Secret Owned', () {
      final f = CollectionShelfFilters.empty
          .toggleSecretOwned()
          .toggleSecretMissing();
      expect(f.secretOwned, isFalse);
      expect(f.secretMissing, isTrue);
      expect(f.activeCount, 1);
    });

    test('tapping selected Secret Owned clears it', () {
      final f = CollectionShelfFilters.empty
          .toggleSecretOwned()
          .toggleSecretOwned();
      expect(f.secretOwned, isFalse);
    });
  });

  group('Collection Attributes remain combinable', () {
    test('Has Duplicates and Custom Series AND together', () {
      final f = CollectionShelfFilters.empty
          .copyWith(hasDuplicates: true)
          .copyWith(customSeries: true);
      expect(f.hasDuplicates, isTrue);
      expect(f.customSeries, isTrue);
      expect(f.activeCount, 2);
    });
  });

  group('Brand and IP single selection', () {
    test('Brand toggle replaces previous selection', () {
      final f = CollectionShelfFilters.empty
          .toggleBrandId('popmart')
          .toggleBrandId('toptoy');
      expect(f.brandIds, {'toptoy'});
      expect(f.activeCount, 1);
    });

    test('Brand toggle clears when tapping the selected id', () {
      final f = CollectionShelfFilters.empty
          .toggleBrandId('popmart')
          .toggleBrandId('popmart');
      expect(f.brandIds, isEmpty);
    });

    test('IP toggle is single-select with clear', () {
      final f = CollectionShelfFilters.empty
          .toggleIpId('labubu')
          .toggleIpId('hirono')
          .toggleIpId('hirono');
      expect(f.ipIds, isEmpty);
    });
  });

  group('Brand-dependent IP options and prune', () {
    late List<ShelfSeries> shelf;

    setUp(() {
      shelf = [
        testShelfSeries(
          id: 'pm_labubu',
          name: 'Labubu',
          brand: 'POP MART',
          taxonomyBrandId: 'popmart',
          taxonomyIpId: 'labubu',
          figures: [
            const ShelfFigure(
              id: 'a',
              seriesId: 'pm_labubu',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
        testShelfSeries(
          id: 'pm_hirono',
          name: 'Hirono',
          brand: 'POP MART',
          taxonomyBrandId: 'popmart',
          taxonomyIpId: 'hirono',
          figures: [
            const ShelfFigure(
              id: 'b',
              seriesId: 'pm_hirono',
              name: 'B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
        testShelfSeries(
          id: 'tt_other',
          name: 'Other',
          brand: 'TOP TOY',
          taxonomyBrandId: 'toptoy',
          taxonomyIpId: 'nommi',
          figures: [
            const ShelfFigure(
              id: 'c',
              seriesId: 'tt_other',
              name: 'C',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ];
    });

    test('clearing Brand keeps IP when still available', () {
      final filters = CollectionShelfFilters(
        brandIds: {'popmart'},
        ipIds: {'labubu'},
      );
      final pruned = pruneCollectionShelfIpIdsToBrandScope(
        filters.copyWith(brandIds: const {}),
        shelf,
      );
      expect(pruned.ipIds, {'labubu'});
    });

    test('changing Brand clears incompatible IP', () {
      final filters = CollectionShelfFilters(
        brandIds: {'popmart'},
        ipIds: {'labubu'},
      );
      final pruned = pruneCollectionShelfIpIdsToBrandScope(
        filters.copyWith(brandIds: {'toptoy'}),
        shelf,
      );
      expect(pruned.brandIds, {'toptoy'});
      expect(pruned.ipIds, isEmpty);
    });

    test('preview count uses AND across Brand and IP', () {
      final states = <String, TrackedFigure>{
        'a': const TrackedFigure(
          figureId: 'a',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
        'b': const TrackedFigure(
          figureId: 'b',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
        'c': const TrackedFigure(
          figureId: 'c',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };
      final preview = previewCollectionShelfFilterResults(
        shelfSeries: shelf,
        figureStates: states,
        filters: CollectionShelfFilters(
          brandIds: {'popmart'},
          ipIds: {'labubu'},
        ),
      );
      expect(preview.waitingOnCatalog, isFalse);
      expect(preview.count, 1);
      expect(preview.series.single.id, 'pm_labubu');
    });
  });

  group('facet collapse planner', () {
    test('fits chips into two rows and reports hidden count', () {
      final plan = planCollectionShelfFacetCollapse(
        chipWidths: const [80, 80, 80, 80, 80, 80],
        maxWidth: 200,
        spacing: 8,
        maxRows: 2,
      );
      // row1: 80+8+80 = 168; cannot fit third → wrap
      // row2: 80+8+80 = 168; cannot fit third → stop
      expect(plan.visibleCount, 4);
      expect(plan.hiddenCount, 2);
      expect(plan.needsShowMore, isTrue);
    });

    test('selected option is prioritized to the front', () {
      final ordered = prioritizeSelectedFacetOption(
        ordered: const ['a', 'b', 'c'],
        isSelected: (o) => o == 'c',
      );
      expect(ordered, ['c', 'a', 'b']);
    });

    test('narrow width still keeps at least the first chip', () {
      final plan = planCollectionShelfFacetCollapse(
        chipWidths: const [180, 180, 180],
        maxWidth: 120,
        spacing: 8,
        maxRows: 2,
      );
      expect(plan.visibleCount, 2);
      expect(plan.hiddenCount, 1);
    });
  });

  group('Filters sheet Brand/IP and Secret Status UI', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required List<ShelfSeries> shelf,
      CollectionShelfFilters initial = CollectionShelfFilters.empty,
      Map<String, TrackedFigure> figureStates = const {},
      Size surface = const Size(390, 844),
    }) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final snap = CollectionSnapshot(
        shelfSeries: shelf,
        figureStates: figureStates,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              () => _GroupsTestCollectionNotifier(snap),
            ),
            catalogBundleProvider.overrideWith(
              (ref) async => const CatalogSeedBundle(
                brands: [],
                ips: [],
                series: [],
                figures: [],
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () {
                      showCollectionShelfFiltersSheet(
                        context: context,
                        initial: initial,
                        shelfSeries: shelf,
                        figureStates: figureStates,
                      );
                    },
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shows Secret Status section and All Brand header', (
      tester,
    ) async {
      final shelf = [
        testShelfSeries(
          id: 's1',
          name: 'Series',
          brand: 'POP MART',
          taxonomyBrandId: 'popmart',
          taxonomyIpId: 'labubu',
          figures: [
            const ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'Fig',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ];
      await pumpSheet(tester, shelf: shelf);
      expect(
        find.text(CollectionVocabulary.filterSectionSecretStatus),
        findsOneWidget,
      );
      expect(
        find.text(CollectionVocabulary.filterSectionCollectionAttributes),
        findsOneWidget,
      );
      expect(find.text(CollectionVocabulary.filterFacetAllSummary), findsWidgets);
      expect(find.text(CollectionVocabulary.secretOwnedFilter), findsOneWidget);
      expect(
        find.text(CollectionVocabulary.hasDuplicatesFilter),
        findsOneWidget,
      );
      // Secrets are not under Attributes wrap as duplicates of section only once
      expect(tester.takeException(), isNull);
    });

    testWidgets('Brand chips visible without accordion expand', (tester) async {
      final shelf = [
        for (var i = 0; i < 8; i++)
          testShelfSeries(
            id: 'b$i',
            name: 'Series $i',
            brand: 'VeryLongBrandNameNumber$i',
            taxonomyBrandId: 'brand$i',
            taxonomyIpId: 'ip$i',
            figures: [
              ShelfFigure(
                id: 'f$i',
                seriesId: 'b$i',
                name: 'Fig',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
      ];
      await pumpSheet(tester, shelf: shelf, surface: const Size(280, 1200));
      expect(find.byKey(const Key('filters_sheet_brand_brand0')), findsOneWidget);
      expect(
        find.byKey(const Key('filters_sheet_brand_show_more')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('filters_sheet_brand_show_more')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('filters_sheet_brand_show_more')));
      await tester.pump();
      expect(find.text(CollectionVocabulary.filterShowLess), findsOneWidget);
    });

    testWidgets('selected Brand stays visible when collapsed', (tester) async {
      final shelf = [
        for (var i = 0; i < 8; i++)
          testShelfSeries(
            id: 'b$i',
            name: 'Series $i',
            brand: 'BrandWithLongName$i',
            taxonomyBrandId: 'brand$i',
            taxonomyIpId: 'ip$i',
            figures: [
              ShelfFigure(
                id: 'f$i',
                seriesId: 'b$i',
                name: 'Fig',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
      ];
      await pumpSheet(
        tester,
        shelf: shelf,
        initial: CollectionShelfFilters(brandIds: {'brand7'}),
        surface: const Size(300, 1200),
      );
      expect(find.byKey(const Key('filters_sheet_brand_brand7')), findsOneWidget);
      expect(find.textContaining('BrandWithLongName7'), findsWidgets);
    });

    testWidgets('restored legacy multi-select is normalized in sheet', (
      tester,
    ) async {
      final shelf = [
        testShelfSeries(
          id: 's1',
          name: 'A',
          brand: 'POP MART',
          taxonomyBrandId: 'popmart',
          taxonomyIpId: 'labubu',
          figures: [
            const ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'Fig',
              rarity: 'Regular',
              isSecret: true,
            ),
          ],
        ),
        testShelfSeries(
          id: 's2',
          name: 'B',
          brand: 'TOP TOY',
          taxonomyBrandId: 'toptoy',
          taxonomyIpId: 'nommi',
          figures: [
            const ShelfFigure(
              id: 'f2',
              seriesId: 's2',
              name: 'Fig',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ];
      await pumpSheet(
        tester,
        shelf: shelf,
        figureStates: const {
          'f1': TrackedFigure(
            figureId: 'f1',
            state: FigureCollectionState.owned,
            ownedQuantity: 1,
          ),
        },
        initial: const CollectionShelfFilters(
          secretOwned: true,
          secretMissing: true,
          brandIds: {'popmart', 'toptoy'},
        ),
      );
      expect(find.byKey(const Key('filters_sheet_secret_owned')), findsOneWidget);
      expect(find.byKey(const Key('filters_sheet_brand_popmart')), findsOneWidget);
      // Both Brand options remain listed; header shows the normalized single Brand.
      expect(find.byKey(const Key('filters_sheet_brand_toptoy')), findsOneWidget);
      expect(find.text('POP MART'), findsWidgets);
      // Secret Status + single Brand AND → only the owned-secret POP MART series.
      expect(find.text('Show results (1)'), findsOneWidget);
    });
  });
}
