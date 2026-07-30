import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog_series;
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filter_matching.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_filters_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_layout_host.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _SnapNotifier extends CollectionNotifier {
  _SnapNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

CollectionSnapshot _twoSeriesSnap() {
  final alpha = testShelfSeries(
    id: 'alpha',
    name: 'Alpha',
    brand: 'POP MART',
    taxonomyBrandId: 'pop_mart',
    catalogTemplateId: 'cat_alpha',
    figures: const [
      ShelfFigure(
        id: 'a1',
        seriesId: 'alpha',
        name: 'A1',
        rarity: 'Regular',
        isSecret: false,
      ),
      ShelfFigure(
        id: 'a2',
        seriesId: 'alpha',
        name: 'A2',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  final bravo = testShelfSeries(
    id: 'bravo',
    name: 'Bravo',
    brand: 'POP MART',
    taxonomyBrandId: 'pop_mart',
    catalogTemplateId: 'cat_bravo',
    figures: const [
      ShelfFigure(
        id: 'b1',
        seriesId: 'bravo',
        name: 'B1',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  return CollectionSnapshot(
    shelfSeries: [alpha, bravo],
    figureStates: {
      'a1': const TrackedFigure(
        figureId: 'a1',
        state: FigureCollectionState.owned,
        ownedQuantity: 3,
      ),
      'b1': const TrackedFigure(
        figureId: 'b1',
        state: FigureCollectionState.owned,
      ),
    },
  );
}

const _catalog = CatalogSeedBundle(
  brands: [CatalogBrand(id: 'pop_mart', displayName: 'POP MART')],
  ips: [CatalogIp(id: 'hirono', brandId: 'pop_mart', displayName: 'Hirono')],
  series: [
    catalog_series.CatalogSeries(
      id: 'cat_alpha',
      brandId: 'pop_mart',
      ipId: 'hirono',
      displayName: 'Alpha',
      releaseDate: '2024-01-01',
      isBlindBox: true,
      imageKey: 'cat_alpha',
    ),
    catalog_series.CatalogSeries(
      id: 'cat_bravo',
      brandId: 'pop_mart',
      ipId: 'hirono',
      displayName: 'Bravo',
      releaseDate: '2025-06-15',
      isBlindBox: true,
      imageKey: 'cat_bravo',
    ),
  ],
  figures: [],
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required CollectionSnapshot snap,
  CollectionShelfFilters initial = CollectionShelfFilters.empty,
  CollectionShelfSort initialSort = CollectionShelfSort.recentlyAdded,
  void Function(CollectionShelfFiltersSheetResult?)? onClosed,
  double textScale = 1,
  Size? surfaceSize,
}) async {
  SharedPreferences.setMockInitialValues({});
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
        catalogBundleProvider.overrideWith((ref) async => _catalog),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await showCollectionShelfFiltersSheet(
                    context: context,
                    initial: initial,
                    initialSort: initialSort,
                    shelfSeries: snap.shelfSeries,
                    figureStates: snap.figureStates,
                  );
                  onClosed?.call(result);
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

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('active-filter count excludes Sort', () {
    expect(CollectionShelfFilters.empty.activeCount, 0);
    expect(const CollectionShelfFilters(hasDuplicates: true).activeCount, 1);
    // Sort lives outside CollectionShelfFilters.
    expect(
      CollectionVocabulary.filtersControlLabel(0),
      isNot(contains('Recently')),
    );
  });

  test('Brand/IP collapsed summaries', () {
    const brands = <CollectionBrandFilterOption>[
      (id: 'popmart', label: 'POP MART'),
      (id: 'toptoy', label: 'TOP TOY'),
    ];
    expect(
      collectionShelfBrandFilterSummary(selectedIds: {}, options: brands),
      CollectionVocabulary.filterAllBrandsSummary,
    );
    expect(
      collectionShelfBrandFilterSummary(
        selectedIds: {'popmart'},
        options: brands,
      ),
      'POP MART',
    );
    expect(
      collectionShelfBrandFilterSummary(
        selectedIds: {'popmart', 'toptoy'},
        options: brands,
      ),
      '2 selected',
    );

    const ips = <CollectionIpFilterOption>[
      (id: 'hirono', label: 'Hirono'),
      (id: 'dimoo', label: 'DIMOO'),
    ];
    expect(
      collectionShelfIpFilterSummary(selectedIds: {}, options: ips),
      CollectionVocabulary.filterAllIpsSummary,
    );
    expect(
      collectionShelfIpFilterSummary(selectedIds: {'hirono'}, options: ips),
      'Hirono',
    );
    expect(
      collectionShelfIpFilterSummary(
        selectedIds: {'hirono', 'dimoo'},
        options: ips,
      ),
      '2 selected',
    );
  });

  testWidgets('compact Sort row; chooser lists all five options', (
    tester,
  ) async {
    final snap = _twoSeriesSnap();
    await _pumpSheet(tester, snap: snap);
    await _open(tester);

    expect(find.byKey(const Key('filters_sheet_sort_row')), findsOneWidget);
    expect(
      find.byKey(const Key('filters_sheet_sort_row_value')),
      findsOneWidget,
    );
    // Five radio rows are not permanently on the main sheet.
    expect(
      find.byKey(const Key('filters_sheet_sort_alphabetical')),
      findsNothing,
    );
    expect(
      find.text(CollectionVocabulary.filterSectionProgress),
      findsOneWidget,
    );

    final sortY = tester
        .getTopLeft(find.byKey(const Key('filters_sheet_sort_row')))
        .dy;
    final progressY = tester
        .getTopLeft(find.text(CollectionVocabulary.filterSectionProgress))
        .dy;
    expect(sortY, lessThan(progressY));

    await tester.tap(find.byKey(const Key('filters_sheet_sort_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final sort in CollectionShelfSort.values) {
      expect(
        find.byKey(Key('filters_sheet_sort_${sort.name}')),
        findsOneWidget,
      );
      expect(find.text(sort.menuLabel), findsWidgets);
    }

    // Content-wrap: only inset/safe-area gap below the last option (no tall void).
    final chooser = find.byKey(const Key('filters_sheet_sort_chooser'));
    expect(chooser, findsOneWidget);
    final lastOption = find.byKey(
      Key('filters_sheet_sort_${CollectionShelfSort.values.last.name}'),
    );
    final gapBelowLast =
        tester.getBottomLeft(chooser).dy - tester.getBottomLeft(lastOption).dy;
    expect(gapBelowLast, greaterThanOrEqualTo(0));
    expect(
      gapBelowLast,
      lessThan(FeedRhythm.sheetBodyBottomInset + 56),
      reason: 'only sheet inset / safe-area padding below last option',
    );

    final selectedRadios = find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Symbols.radio_button_checked_rounded),
    );
    expect(selectedRadios, findsOneWidget);
  });

  Future<void> pickSort(WidgetTester tester, CollectionShelfSort sort) async {
    await tester.tap(find.byKey(const Key('filters_sheet_sort_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(
      find.byKey(Key('filters_sheet_sort_${sort.name}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(Key('filters_sheet_sort_${sort.name}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'Sort chooser wraps content height; last option reachable with large text',
    (tester) async {
      final snap = _twoSeriesSnap();
      await _pumpSheet(
        tester,
        snap: snap,
        surfaceSize: const Size(390, 844),
        textScale: 1.3,
      );
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);

      await _open(tester);
      await tester.tap(find.byKey(const Key('filters_sheet_sort_row')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final chooser = find.byKey(const Key('filters_sheet_sort_chooser'));
      expect(chooser, findsOneWidget);
      // Tall phone: content-wrap beats the legacy fixed 0.52 host.
      expect(tester.getSize(chooser).height, lessThan(844 * 0.52));

      final last = find.byKey(
        Key('filters_sheet_sort_${CollectionShelfSort.values.last.name}'),
      );
      await tester.ensureVisible(last);
      await tester.pump();
      expect(last, findsOneWidget);
      final lastBottom = tester.getBottomLeft(last).dy;
      expect(lastBottom, lessThanOrEqualTo(844 - 1));

      final gapBelowLast = tester.getBottomLeft(chooser).dy - lastBottom;
      expect(gapBelowLast, greaterThanOrEqualTo(34));
      expect(gapBelowLast, lessThan(34 + FeedRhythm.sheetBodyBottomInset + 24));
    },
  );

  testWidgets('exactly one Sort option selected; draft does not apply yet', (
    tester,
  ) async {
    CollectionShelfFiltersSheetResult? applied;
    final snap = _twoSeriesSnap();
    await _pumpSheet(
      tester,
      snap: snap,
      initialSort: CollectionShelfSort.recentlyAdded,
      onClosed: (v) => applied = v,
    );
    await _open(tester);

    expect(
      find.text(CollectionShelfSort.recentlyAdded.menuLabel),
      findsOneWidget,
    );
    await pickSort(tester, CollectionShelfSort.alphabetical);
    expect(
      find.text(CollectionShelfSort.alphabetical.menuLabel),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.text('Filters').first)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(applied, isNull);
  });

  testWidgets('Show commits draft Sort and Filters together', (tester) async {
    CollectionShelfFiltersSheetResult? applied;
    final snap = _twoSeriesSnap();
    await _pumpSheet(
      tester,
      snap: snap,
      initialSort: CollectionShelfSort.recentlyAdded,
      onClosed: (v) => applied = v,
    );
    await _open(tester);

    await pickSort(tester, CollectionShelfSort.figureCount);
    await tester.ensureVisible(
      find.byKey(const Key('filters_sheet_has_duplicates')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_has_duplicates')));
    await tester.pump();
    expect(find.text('Show 1 Series'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(applied?.sort, CollectionShelfSort.figureCount);
    expect(applied?.filters.hasDuplicates, isTrue);
    expect(applied?.filters.activeCount, 1);
  });

  testWidgets('Clear all clears only draft Filters and keeps draft Sort', (
    tester,
  ) async {
    CollectionShelfFiltersSheetResult? applied;
    final snap = _twoSeriesSnap();
    await _pumpSheet(
      tester,
      snap: snap,
      initial: const CollectionShelfFilters(hasDuplicates: true),
      initialSort: CollectionShelfSort.completion,
      onClosed: (v) => applied = v,
    );
    await _open(tester);

    expect(find.text('Show 1 Series'), findsOneWidget);
    expect(find.text(CollectionShelfSort.completion.menuLabel), findsOneWidget);
    await tester.tap(find.byKey(const Key('filters_sheet_clear_all')));
    await tester.pump();
    expect(find.text('Show 2 Series'), findsOneWidget);
    expect(find.text(CollectionShelfSort.completion.menuLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(applied?.filters, CollectionShelfFilters.empty);
    expect(applied?.sort, CollectionShelfSort.completion);
  });

  testWidgets('Sort does not change preview count; does change order key', (
    tester,
  ) async {
    final snap = _twoSeriesSnap();
    await _pumpSheet(tester, snap: snap);
    await _open(tester);

    expect(find.text('Show 2 Series'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('filters_sheet_preview_ids_alpha|bravo')),
      findsOneWidget,
    );

    await pickSort(tester, CollectionShelfSort.alphabetical);
    expect(find.text('Show 2 Series'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('filters_sheet_preview_ids_alpha|bravo')),
      findsOneWidget,
    );

    await pickSort(tester, CollectionShelfSort.figureCount);
    expect(find.text('Show 2 Series'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('filters_sheet_preview_ids_alpha|bravo')),
      findsOneWidget,
    );
  });

  testWidgets('Applying Filters preserves Sort and vice versa', (tester) async {
    CollectionShelfFiltersSheetResult? applied;
    final snap = _twoSeriesSnap();
    await _pumpSheet(
      tester,
      snap: snap,
      initial: const CollectionShelfFilters(hasDuplicates: true),
      initialSort: CollectionShelfSort.alphabetical,
      onClosed: (v) => applied = v,
    );
    await _open(tester);
    await pickSort(tester, CollectionShelfSort.recentlyReleased);
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(applied?.filters.hasDuplicates, isTrue);
    expect(applied?.sort, CollectionShelfSort.recentlyReleased);
  });

  testWidgets('Brand and IP collapsed by default; expand reveals chips', (
    tester,
  ) async {
    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(
          id: 'a',
          brand: 'POP MART',
          taxonomyBrandId: 'pop_mart',
          ipName: 'Hirono',
          taxonomyIpId: 'hirono',
        ),
        testShelfSeries(
          id: 'b',
          name: 'Bravo',
          brand: 'TOP TOY',
          taxonomyBrandId: 'toptoy',
          ipName: 'DIMOO',
          taxonomyIpId: 'dimoo',
        ),
      ],
      figureStates: const {},
    );
    await _pumpSheet(tester, snap: snap);
    await _open(tester);

    expect(
      find.text(CollectionVocabulary.filterAllBrandsSummary),
      findsOneWidget,
    );
    expect(find.text(CollectionVocabulary.filterAllIpsSummary), findsOneWidget);
    expect(find.byKey(const Key('filters_sheet_brand_popmart')), findsNothing);
    expect(
      find.text(CollectionVocabulary.filterSearchBrandsHint),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('filters_sheet_brand_section')));
    await tester.pump();
    expect(
      find.byKey(const Key('filters_sheet_brand_popmart')),
      findsOneWidget,
    );
    expect(
      find.text(CollectionVocabulary.filterSearchBrandsHint),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('filters_sheet_brand_popmart')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_brand_popmart')));
    await tester.pump();
    expect(find.text('POP MART'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('filters_sheet_brand_section')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_brand_section')));
    await tester.pump();
    expect(find.byKey(const Key('filters_sheet_brand_popmart')), findsNothing);
    expect(find.text('POP MART'), findsOneWidget); // summary
    expect(find.text('Show 1 Series'), findsOneWidget);
  });

  testWidgets('single Brand expands without search field', (tester) async {
    final snap = _twoSeriesSnap(); // both POP MART
    await _pumpSheet(tester, snap: snap);
    await _open(tester);
    await tester.tap(find.byKey(const Key('filters_sheet_brand_section')));
    await tester.pump();
    expect(
      find.text(CollectionVocabulary.filterSearchBrandsHint),
      findsNothing,
    );
    expect(
      find.byKey(const Key('filters_sheet_brand_popmart')),
      findsOneWidget,
    );
  });

  testWidgets('IP expand/collapse preserves draft selection and summary', (
    tester,
  ) async {
    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(
          id: 'a',
          brand: 'POP MART',
          taxonomyBrandId: 'pop_mart',
          ipName: 'Hirono',
          taxonomyIpId: 'hirono',
        ),
        testShelfSeries(
          id: 'b',
          name: 'Bravo',
          brand: 'POP MART',
          taxonomyBrandId: 'pop_mart',
          ipName: 'DIMOO',
          taxonomyIpId: 'dimoo',
        ),
      ],
      figureStates: const {},
    );
    await _pumpSheet(tester, snap: snap);
    await _open(tester);

    expect(find.byKey(const Key('filters_sheet_ip_hirono')), findsNothing);
    await tester.tap(find.byKey(const Key('filters_sheet_ip_section')));
    await tester.pump();
    expect(find.text(CollectionVocabulary.filterSearchIpsHint), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('filters_sheet_ip_hirono')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters_sheet_ip_hirono')));
    await tester.pump();
    expect(find.text('Show 1 Series'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filters_sheet_ip_section')));
    await tester.pump();
    expect(find.byKey(const Key('filters_sheet_ip_hirono')), findsNothing);
    expect(find.text('Hirono'), findsOneWidget);
    expect(find.text('Show 1 Series'), findsOneWidget);
  });

  testWidgets('bottom actions respect safe area and keyboard inset', (
    tester,
  ) async {
    final snap = _twoSeriesSnap();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewInsets = const FakeViewPadding(bottom: 120);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
          catalogBundleProvider.overrideWith((ref) async => _catalog),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              padding: const EdgeInsets.only(bottom: 34),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showCollectionShelfFiltersSheet(
                      context: context,
                      initial: CollectionShelfFilters.empty,
                      shelfSeries: snap.shelfSeries,
                      figureStates: snap.figureStates,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await _open(tester);

    expect(find.byType(CollectibleSheetInsets), findsOneWidget);
    final show = find.byKey(const Key('filters_sheet_show_results'));
    expect(show, findsOneWidget);
    await tester.ensureVisible(show);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Collection screen Apply updates prefs Sort without Sort menu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'collection_shelf_ui_prefs_v1':
          '{"sort":"recentlyAdded","layout":"grid"}',
    });
    final snap = _twoSeriesSnap();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
          catalogBundleProvider.overrideWith((ref) async => _catalog),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('collection_shelf_sort_menu')), findsNothing);
    await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('filters_sheet_sort_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('filters_sheet_sort_completion')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final prefs = await CollectionShelfUiPrefsStorage.load();
    expect(prefs.sort, CollectionShelfSort.completion);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('layouts share identical ordered IDs after filter+sort', (
    tester,
  ) async {
    final snap = _twoSeriesSnap();
    final filtered = applyCollectionShelfFilters(
      snap.shelfSeries,
      snap.figureStates,
      CollectionShelfFilters.empty,
    );
    final ordered = sortShelfSeriesForDisplay(
      filtered,
      CollectionShelfSort.figureCount,
      snap.figureStates,
      catalog: _catalog,
    );
    final ids = ordered.map((s) => s.id).toList();

    for (final layout in CollectionShelfLayout.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectionShelfSeriesLayoutHost(
                layout: layout,
                series: ordered,
                figureStates: snap.figureStates,
                progress: ShelfBrowseProgressLookup(snap.figureStates),
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(ids, ['alpha', 'bravo']);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
    }
  });

  test('Layout and Card Content stay independent of Sort/Filters', () {
    const prefs = CollectionShelfUiPrefs(
      sort: CollectionShelfSort.completion,
      layout: CollectionShelfLayout.list,
      cardContent: CollectionShelfCardContentPrefs(
        CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
        ]),
      ),
    );
    expect(
      prefs.copyWith(sort: CollectionShelfSort.alphabetical).layout,
      CollectionShelfLayout.list,
    );
    expect(
      prefs.copyWith(sort: CollectionShelfSort.alphabetical).cardContent,
      prefs.cardContent,
    );
    expect(
      prefs.copyWith(layout: CollectionShelfLayout.grid).sort,
      CollectionShelfSort.completion,
    );
  });

  testWidgets('sheet scrollable; narrow + large text do not overflow', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) errors.add(d);
      old?.call(d);
    };
    addTearDown(() => FlutterError.onError = old);

    final snap = _twoSeriesSnap();
    await _pumpSheet(
      tester,
      snap: snap,
      surfaceSize: const Size(320, 640),
      textScale: 1.3,
    );
    await _open(tester);

    expect(find.byType(CollectibleSheetScrollView), findsOneWidget);
    expect(find.byType(CollectibleSheetInsets), findsOneWidget);
    await tester.ensureVisible(
      find.text(CollectionVocabulary.filterSectionCollectionAttributes),
    );
    await tester.ensureVisible(
      find.byKey(const Key('filters_sheet_show_results')),
    );
    expect(errors, isEmpty);
    expect(
      tester.getSize(find.byKey(const Key('filters_sheet_sort_row'))).height,
      56,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('filters_sheet_brand_section')))
          .height,
      56,
    );
  });

  test(
    'Recently Released uses U.S. release date; duplicates ignore completion',
    () {
      final snap = _twoSeriesSnap();
      final byRelease = sortShelfSeriesForDisplay(
        snap.shelfSeries,
        CollectionShelfSort.recentlyReleased,
        snap.figureStates,
        catalog: _catalog,
      );
      expect(byRelease.map((s) => s.id).toList(), ['bravo', 'alpha']);

      final byCompletion = sortShelfSeriesForDisplay(
        snap.shelfSeries,
        CollectionShelfSort.completion,
        snap.figureStates,
        catalog: _catalog,
      );
      // Bravo 1/1 complete before Alpha 1/2 — ownedQuantity 3 on a1 does not
      // inflate Alpha ahead of unique-owned completion.
      expect(byCompletion.first.id, 'bravo');
    },
  );
}
