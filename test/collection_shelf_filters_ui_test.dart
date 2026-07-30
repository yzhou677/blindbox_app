import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_filters_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/figure_capsule_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _FiltersTestCollectionNotifier extends CollectionNotifier {
  _FiltersTestCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

CollectionSnapshot _shelfWithDuplicates() {
  final withDups = testShelfSeries(
    id: 'with_dups',
    name: 'Dup Series',
    figures: const [
      ShelfFigure(
        id: 'd1',
        seriesId: 'with_dups',
        name: 'Dup Fig',
        rarity: 'Regular',
        isSecret: false,
      ),
      ShelfFigure(
        id: 'd2',
        seriesId: 'with_dups',
        name: 'Dup Missing',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  final single = testShelfSeries(
    id: 'single_copy',
    name: 'Single Series',
    figures: const [
      ShelfFigure(
        id: 's1',
        seriesId: 'single_copy',
        name: 'Single Fig',
        rarity: 'Regular',
        isSecret: false,
      ),
      ShelfFigure(
        id: 's2',
        seriesId: 'single_copy',
        name: 'Single Missing',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  return CollectionSnapshot(
    shelfSeries: [withDups, single],
    figureStates: {
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
    },
  );
}

Future<void> _pumpCollection(
  WidgetTester tester,
  CollectionSnapshot snap,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _FiltersTestCollectionNotifier(snap),
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
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: const CollectionScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpFiltersSheetHost(
  WidgetTester tester,
  CollectionSnapshot snap, {
  CollectionShelfFilters initial = CollectionShelfFilters.empty,
  CollectionShelfSort initialSort = CollectionShelfSort.recentlyAdded,
  void Function(CollectionShelfFiltersSheetResult?)? onClosed,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _FiltersTestCollectionNotifier(snap),
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
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  final applied = await showCollectionShelfFiltersSheet(
                    context: context,
                    initial: initial,
                    initialSort: initialSort,
                    shelfSeries: snap.shelfSeries,
                    figureStates: snap.figureStates,
                  );
                  onClosed?.call(applied);
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _tapSheetKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _openFiltersSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _applyFiltersSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CollectionShelfFilters activeCount and clear', () {
    expect(CollectionShelfFilters.empty.activeCount, 0);
    expect(const CollectionShelfFilters(hasDuplicates: true).activeCount, 1);
    expect(
      const CollectionShelfFilters(hasDuplicates: true).cleared(),
      CollectionShelfFilters.empty,
    );
    expect(CollectionVocabulary.filtersControlLabel(0), 'Filters');
    expect(CollectionVocabulary.filtersControlLabel(1), 'Filters · 1');
  });

  test('Has Duplicates filter keeps matching series and excludes others', () {
    final snap = _shelfWithDuplicates();
    final filtered = shelfSeriesVisibleForDuplicatesFilter(
      snap.shelfSeries,
      snap.figureStates,
      hasDuplicatesOnly: true,
    );
    expect(filtered.map((s) => s.id), ['with_dups']);
    expect(
      shelfSeriesVisibleForDuplicatesFilter(
        snap.shelfSeries,
        snap.figureStates,
        hasDuplicatesOnly: false,
      ),
      hasLength(2),
    );
  });

  testWidgets('Filters control starts without active count', (tester) async {
    await _pumpCollection(tester, _shelfWithDuplicates());
    expect(
      find.byKey(const Key('collection_shelf_filters_control')),
      findsOneWidget,
    );
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Filters · 1'), findsNothing);
  });

  testWidgets(
    'Activating Has Duplicates shows Filters · 1 after Show results',
    (tester) async {
      await _pumpCollection(tester, _shelfWithDuplicates());

      await _openFiltersSheet(tester);
      expect(
        find.text(CollectionVocabulary.filterSectionCollectionAttributes),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.text(CollectionVocabulary.filterSectionCollectionAttributes),
      );
      await tester.pump();
      await _tapSheetKey(tester, const Key('filters_sheet_has_duplicates'));
      await _applyFiltersSheet(tester);

      expect(find.text('Filters · 1'), findsOneWidget);
      expect(
        find.text('No series with duplicates match these filters.'),
        findsNothing,
      );
    },
  );

  testWidgets('Clear all removes active Filters count', (tester) async {
    await _pumpCollection(tester, _shelfWithDuplicates());

    await _openFiltersSheet(tester);
    await _tapSheetKey(tester, const Key('filters_sheet_has_duplicates'));
    await _applyFiltersSheet(tester);
    expect(find.text('Filters · 1'), findsOneWidget);

    await _openFiltersSheet(tester);
    await tester.tap(find.byKey(const Key('filters_sheet_clear_all')));
    await tester.pump();
    await _applyFiltersSheet(tester);

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Filters · 1'), findsNothing);
  });

  testWidgets('quantity badge uses artwork-relative inset constant', (
    tester,
  ) async {
    final series = testShelfSeries(
      figures: const [
        ShelfFigure(
          id: 'f1',
          seriesId: 'series_test',
          name: 'Owned',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FigureCapsuleCard(
              series: series,
              figure: series.figures.single,
              tracked: const TrackedFigure(
                figureId: 'f1',
                state: FigureCollectionState.owned,
                ownedQuantity: 12,
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(FigureCapsuleCard.quantityBadgeInset, inInclusiveRange(6, 8));
    expect(find.text('×12'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FigureCapsuleCard(
              series: series,
              figure: series.figures.single,
              tracked: const TrackedFigure(
                figureId: 'f1',
                state: FigureCollectionState.owned,
                ownedQuantity: 2,
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('filters sheet Apply returns draft state', (tester) async {
    CollectionShelfFiltersSheetResult? applied;
    final snap = _shelfWithDuplicates();
    await _pumpFiltersSheetHost(tester, snap, onClosed: (v) => applied = v);
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _tapSheetKey(tester, const Key('filters_sheet_has_duplicates'));
    expect(find.text('Show 1 Series'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(applied?.filters.hasDuplicates, isTrue);
    expect(applied?.filters.activeCount, 1);
    expect(applied?.sort, CollectionShelfSort.recentlyAdded);
  });

  testWidgets('Dismiss without Apply preserves previous filters', (
    tester,
  ) async {
    CollectionShelfFiltersSheetResult? applied;
    final snap = _shelfWithDuplicates();
    await _pumpFiltersSheetHost(
      tester,
      snap,
      initial: const CollectionShelfFilters(hasDuplicates: true),
      onClosed: (v) => applied = v,
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _tapSheetKey(tester, const Key('filters_sheet_has_duplicates'));
    Navigator.of(tester.element(find.text('Filters').first)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(applied, isNull);
  });

  testWidgets('Clear all removes every draft filter', (tester) async {
    CollectionShelfFiltersSheetResult? applied;
    final snap = _shelfWithDuplicates();
    await _pumpFiltersSheetHost(
      tester,
      snap,
      initial: const CollectionShelfFilters(
        hasDuplicates: true,
        secretOwned: true,
      ),
      onClosed: (v) => applied = v,
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('filters_sheet_clear_all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(applied?.filters, CollectionShelfFilters.empty);
  });

  testWidgets('Filters sheet Sort by precedes Progress; no Time section', (
    tester,
  ) async {
    final snap = _shelfWithDuplicates();
    await _pumpFiltersSheetHost(tester, snap);
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Time'), findsNothing);
    expect(find.byKey(const Key('filters_sheet_sort_row')), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(
      find.byKey(const Key('filters_sheet_sort_alphabetical')),
      findsNothing,
    );
    expect(find.text('Collection Attributes'), findsOneWidget);
    expect(find.text('Metadata'), findsNothing);

    final sortTop = tester
        .getTopLeft(find.byKey(const Key('filters_sheet_sort_row')))
        .dy;
    final progressTop = tester
        .getTopLeft(find.text(CollectionVocabulary.filterSectionProgress))
        .dy;
    expect(sortTop, lessThan(progressTop));
  });

  testWidgets('filters sheet exposes Brand chips from shelf data', (
    tester,
  ) async {
    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(
          id: 'a',
          brand: 'POP MART',
          taxonomyBrandId: 'pop_mart',
        ),
        testShelfSeries(
          id: 'b',
          brand: 'TOP TOY',
          taxonomyBrandId: 'toptoy',
          name: 'Bravo',
        ),
      ],
      figureStates: const {},
    );
    await _pumpFiltersSheetHost(tester, snap);
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Brand'), findsWidgets);
    expect(
      find.text(CollectionVocabulary.filterAllBrandsSummary),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('filters_sheet_brand_section')));
    await tester.pump();
    expect(
      find.byKey(const Key('filters_sheet_brand_popmart')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('filters_sheet_brand_toptoy')), findsOneWidget);
  });
}
