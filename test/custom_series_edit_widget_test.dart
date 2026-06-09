import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

const _emptyCatalog = CatalogSeedBundle(
  brands: [],
  ips: [],
  series: [],
  figures: [],
);

final class _CustomSeriesEditTestNotifier extends CollectionNotifier {
  _CustomSeriesEditTestNotifier(this._snap);
  CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;

  @override
  void updateCustomSeries({
    required String seriesId,
    required String seriesName,
    String? brand,
    String? ipDisplayName,
    String? customCoverImageUri,
    String? notes,
  }) {
    super.updateCustomSeries(
      seriesId: seriesId,
      seriesName: seriesName,
      brand: brand,
      ipDisplayName: ipDisplayName,
      customCoverImageUri: customCoverImageUri,
      notes: notes,
    );
    _snap = state;
  }
}

ShelfSeries _customSeries() {
  const seriesId = 'custom_widget_test';
  return ShelfSeries(
    id: seriesId,
    name: 'Widget Test Set',
    brand: 'DPL',
    ipName: 'Baby Three',
    taxonomyBrandId: 'dpl',
    taxonomyIpId: 'baby_three',
    catalogTemplateId: null,
    imageKey: seriesId,
    figures: const [
      ShelfFigure(
        id: 'custom_widget_test-f-0',
        seriesId: seriesId,
        name: 'One',
        rarity: 'Regular',
        isSecret: false,
        taxonomyBrandId: 'dpl',
        taxonomyIpId: 'baby_three',
      ),
    ],
    shelfAccent: Color(0xFFE4F2EA),
  );
}

List<Override> _sheetOverrides(CollectionNotifier Function() notifierFactory) {
  return [
    collectionNotifierProvider.overrideWith(notifierFactory),
    catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
  ];
}

Future<void> _pumpFiguresSheet(
  WidgetTester tester, {
  required ShelfSeries series,
  required CollectionNotifier Function() notifierFactory,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _sheetOverrides(notifierFactory),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectibleSheetScope(
            scrollController: ScrollController(),
            child: SeriesFiguresSheet(seriesId: series.id),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _textFieldAt(int index) {
  return find.descendant(
    of: find.byType(CustomSeriesFormSheet),
    matching: find.byType(TextFormField),
  ).at(index);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  testWidgets('custom series figures sheet exposes Edit series action', (
    tester,
  ) async {
    final series = _customSeries();
    await _pumpFiguresSheet(
      tester,
      series: series,
      notifierFactory: () => _CustomSeriesEditTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      ),
    );

    expect(find.text('Edit series'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
  });

  testWidgets('catalog series figures sheet does not expose Edit series', (
    tester,
  ) async {
    final series = testShelfSeries();
    await _pumpFiguresSheet(
      tester,
      series: series,
      notifierFactory: () => _CustomSeriesEditTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      ),
    );

    expect(find.text('Edit series'), findsNothing);
  });

  testWidgets('edit form saves metadata and shelf filter chips update', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final series = _customSeries();
    final notifier = _CustomSeriesEditTestNotifier(
      CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._sheetOverrides(() => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: Builder(
                builder: (ctx) => CustomSeriesFormSheet.edit(
                  initialSeries: series,
                  onSubmit:
                      ({
                        required String seriesName,
                        String? brand,
                        String? ipDisplayName,
                        String? customCoverImageUri,
                        String? notes,
                      }) {
                        ProviderScope.containerOf(ctx)
                            .read(collectionNotifierProvider.notifier)
                            .updateCustomSeries(
                              seriesId: series.id,
                              seriesName: seriesName,
                              brand: brand,
                              ipDisplayName: ipDisplayName,
                              customCoverImageUri: customCoverImageUri,
                              notes: notes,
                            );
                      },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    ProviderScope.containerOf(
      tester.element(find.byType(CustomSeriesFormSheet)),
    ).read(collectionNotifierProvider);

    expect(find.text('Edit series'), findsOneWidget);
    expect(find.byType(CustomSeriesFormSheet), findsOneWidget);

    await tester.enterText(_textFieldAt(1), 'POP MART');
    await tester.enterText(_textFieldAt(2), 'THE MONSTERS');

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final updated = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(updated.brand, 'POP MART');
    expect(updated.taxonomyBrandId, 'pop_mart');
    expect(updated.ipName, 'THE MONSTERS');
    expect(updated.taxonomyIpId, 'the_monsters');
    expect(updated.figures.single.taxonomyBrandId, 'pop_mart');
    expect(updated.figures.single.taxonomyIpId, 'the_monsters');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._sheetOverrides(() => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('POP MART'), findsAtLeastNWidgets(1));
    expect(find.text('THE MONSTERS'), findsAtLeastNWidgets(1));
    expect(find.text('DPL'), findsNothing);
    expect(find.byType(TaxonomyBrandChipRail), findsNWidgets(2));
  });
}
