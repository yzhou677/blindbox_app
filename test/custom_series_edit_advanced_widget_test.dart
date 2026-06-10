import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_cover_slot.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptyCatalog = CatalogSeedBundle(
  brands: [],
  ips: [],
  series: [],
  figures: [],
);

final class _EditAdvancedTestNotifier extends CollectionNotifier {
  _EditAdvancedTestNotifier(this._snap);
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

  @override
  void updateCustomFigure({
    required String seriesId,
    required String figureId,
    required String name,
    required bool isSecret,
    String? rarityLabel,
    String? localImageUri,
  }) {
    super.updateCustomFigure(
      seriesId: seriesId,
      figureId: figureId,
      name: name,
      isSecret: isSecret,
      rarityLabel: rarityLabel,
      localImageUri: localImageUri,
    );
    _snap = state;
  }
}

ShelfSeries _editableSeries({
  String notes = 'Original note',
  String? customCoverImageUri,
}) {
  const seriesId = 'custom_advanced_test';
  return ShelfSeries(
    id: seriesId,
    name: 'Advanced Test Set',
    brand: 'DPL',
    ipName: 'Baby Three',
    taxonomyBrandId: 'dpl',
    taxonomyIpId: 'baby_three',
    catalogTemplateId: null,
    imageKey: seriesId,
    notes: notes,
    customCoverImageUri: customCoverImageUri,
    figures: const [
      ShelfFigure(
        id: 'custom_advanced_test-f-0',
        seriesId: seriesId,
        name: 'Alpha',
        rarity: 'Regular',
        isSecret: false,
        imageKey: 'custom_advanced_test-f-0',
        taxonomyBrandId: 'dpl',
        taxonomyIpId: 'baby_three',
      ),
      ShelfFigure(
        id: 'custom_advanced_test-f-1',
        seriesId: seriesId,
        name: 'Beta',
        rarity: 'Regular',
        isSecret: false,
        imageKey: 'custom_advanced_test-f-1',
        taxonomyBrandId: 'dpl',
        taxonomyIpId: 'baby_three',
      ),
    ],
    shelfAccent: Color(0xFFE4F2EA),
  );
}

Future<ProviderContainer> _pumpEditForm(
  WidgetTester tester, {
  required ShelfSeries series,
  required _EditAdvancedTestNotifier notifier,
}) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(() => notifier),
        catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        initialRoute: '/edit',
        routes: {
          '/': (_) => const Scaffold(body: SizedBox.shrink()),
          '/edit': (ctx) {
            container = ProviderScope.containerOf(ctx);
            return Scaffold(
              body: CollectibleSheetScope(
                scrollController: ScrollController(),
                child: CustomSeriesFormSheet.edit(
                  initialSeries: series,
                  onSubmit:
                      ({
                        required String seriesName,
                        String? brand,
                        String? ipDisplayName,
                        String? customCoverImageUri,
                        String? notes,
                      }) {
                        container
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
                  onFigureSubmit:
                      ({
                        required String figureId,
                        required String name,
                        required bool isSecret,
                        String? rarityLabel,
                        String? localImageUri,
                      }) {
                        container
                            .read(collectionNotifierProvider.notifier)
                            .updateCustomFigure(
                              seriesId: series.id,
                              figureId: figureId,
                              name: name,
                              isSecret: isSecret,
                              rarityLabel: rarityLabel,
                              localImageUri: localImageUri,
                            );
                      },
                  onFigureAdd:
                      ({
                        required String name,
                        required bool isSecret,
                        String? rarityLabel,
                        String? localImageUri,
                      }) {
                        container
                            .read(collectionNotifierProvider.notifier)
                            .addCustomFigure(
                              seriesId: series.id,
                              name: name,
                              isSecret: isSecret,
                              rarityLabel: rarityLabel,
                              localImageUri: localImageUri,
                            );
                      },
                ),
              ),
            );
          },
        },
      ),
    ),
  );
  await tester.pump();
  container.read(collectionNotifierProvider);
  return container;
}

Finder _textFieldAt(int index) {
  return find.descendant(
    of: find.byType(CustomSeriesFormSheet),
    matching: find.byType(TextFormField),
  ).at(index);
}

Future<void> _expandAdvanced(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('custom-series-edit-advanced')));
  await tester.tap(find.text(customSeriesEditAdvancedOptionsTitle));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save changes'));
  await tester.tap(find.text('Save changes'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  group('edit form advanced options UI', () {
    testWidgets('Test 1: default fields visible, brand and IP hidden', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = _editableSeries();
      final notifier = _EditAdvancedTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      await _pumpEditForm(tester, series: series, notifier: notifier);

      expect(find.byType(CustomSeriesCoverSlot), findsOneWidget);
      expect(find.text(customSeriesEditAdvancedOptionsTitle), findsOneWidget);
      expect(find.textContaining('Journey history'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        tester.widget<TextFormField>(_textFieldAt(0)).controller!.text,
        'Advanced Test Set',
      );
    });

    testWidgets('Test 2: expanding advanced shows brand, IP, and warning', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = _editableSeries();
      final notifier = _EditAdvancedTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      await _pumpEditForm(tester, series: series, notifier: notifier);
      await _expandAdvanced(tester);

      expect(find.textContaining('Filters'), findsOneWidget);
      expect(find.textContaining('Grouping'), findsOneWidget);
      expect(find.textContaining('Journey history'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(
        tester.widget<TextFormField>(_textFieldAt(1)).controller!.text,
        'DPL',
      );
      expect(
        tester.widget<TextFormField>(_textFieldAt(2)).controller!.text,
        'Baby Three',
      );
    });

    testWidgets('Test 3: collapsing advanced hides brand and IP', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = _editableSeries();
      final notifier = _EditAdvancedTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      await _pumpEditForm(tester, series: series, notifier: notifier);
      await _expandAdvanced(tester);
      await tester.tap(find.text(customSeriesEditAdvancedOptionsTitle));
      await tester.pumpAndSettle();

      expect(find.textContaining('Journey history'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('edit form save behavior', () {
    testWidgets('Test 4: series name only leaves brand and IP unchanged', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = _editableSeries();
      final notifier = _EditAdvancedTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      final container = await _pumpEditForm(
        tester,
        series: series,
        notifier: notifier,
      );

      await tester.enterText(_textFieldAt(0), 'Renamed Only');
      await _save(tester);

      final updated = container.read(collectionNotifierProvider).shelfSeries.single;
      expect(updated.name, 'Renamed Only');
      expect(updated.brand, 'DPL');
      expect(updated.taxonomyBrandId, 'dpl');
      expect(updated.ipName, 'Baby Three');
      expect(updated.taxonomyIpId, 'baby_three');
      for (final fig in updated.figures) {
        expect(fig.taxonomyBrandId, 'dpl');
        expect(fig.taxonomyIpId, 'baby_three');
      }
    });

    testWidgets('Test 5: advanced brand change canonicalizes and updates filters',
        (tester) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = _editableSeries();
      final notifier = _EditAdvancedTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      final container = await _pumpEditForm(
        tester,
        series: series,
        notifier: notifier,
      );
      await _expandAdvanced(tester);
      await tester.enterText(_textFieldAt(1), 'POP MART');
      await _save(tester);

      final updated = container.read(collectionNotifierProvider).shelfSeries.single;
      expect(updated.brand, 'POP MART');
      expect(updated.taxonomyBrandId, 'pop_mart');
      expect(updated.ipName, 'Baby Three');
      expect(updated.figures.every((f) => f.taxonomyBrandId == 'pop_mart'), isTrue);
    });

    testWidgets('Test 6: advanced IP change canonicalizes and updates filters', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = _editableSeries();
      final notifier = _EditAdvancedTestNotifier(
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      final container = await _pumpEditForm(
        tester,
        series: series,
        notifier: notifier,
      );
      await _expandAdvanced(tester);
      await tester.enterText(_textFieldAt(2), 'the monsters');
      await _save(tester);

      final updated = container.read(collectionNotifierProvider).shelfSeries.single;
      expect(updated.brand, 'DPL');
      expect(updated.ipName, 'THE MONSTERS');
      expect(updated.taxonomyIpId, 'the_monsters');
      expect(updated.figures.every((f) => f.taxonomyIpId == 'the_monsters'), isTrue);
    });

    testWidgets('Test 7: advanced brand and IP change together', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = _editableSeries();
      final notifier = _EditAdvancedTestNotifier(
        CollectionSnapshot(
          shelfSeries: [series],
          figureStates: const {
            'custom_advanced_test-f-0': TrackedFigure(
              figureId: 'custom_advanced_test-f-0',
              state: FigureCollectionState.owned,
            ),
            'custom_advanced_test-f-1': TrackedFigure(
              figureId: 'custom_advanced_test-f-1',
              state: FigureCollectionState.wishlist,
            ),
          },
        ),
      );
      final container = await _pumpEditForm(
        tester,
        series: series,
        notifier: notifier,
      );
      await _expandAdvanced(tester);
      await tester.enterText(_textFieldAt(1), 'dpl');
      await tester.enterText(_textFieldAt(2), 'babythree');
      await tester.enterText(_textFieldAt(3), 'Updated note');
      await _save(tester);

      final snap = container.read(collectionNotifierProvider);
      final updated = snap.shelfSeries.single;
      expect(updated.brand, 'DPL');
      expect(updated.taxonomyBrandId, 'dpl');
      expect(updated.ipName, 'Baby Three');
      expect(updated.taxonomyIpId, 'baby_three');
      expect(updated.notes, 'Updated note');
      expect(updated.figures.map((f) => f.id), [
        'custom_advanced_test-f-0',
        'custom_advanced_test-f-1',
      ]);
      expect(
        snap.trackedOrDefault('custom_advanced_test-f-0').state,
        FigureCollectionState.owned,
      );
      expect(
        snap.trackedOrDefault('custom_advanced_test-f-1').state,
        FigureCollectionState.wishlist,
      );
    });
  });

  testWidgets('create form still shows brand and IP without advanced section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectibleSheetScope(
            scrollController: ScrollController(),
            child: CustomSeriesFormSheet.create(
              onSubmit:
                  ({
                    required String seriesName,
                    String? brand,
                    String? ipDisplayName,
                    required List<CustomFigureDraft> figures,
                    String? customCoverImageUri,
                    String? notes,
                  }) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(customSeriesEditAdvancedOptionsTitle), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });
}
