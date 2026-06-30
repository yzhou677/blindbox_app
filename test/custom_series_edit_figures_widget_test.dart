import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_edit_figures_section.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/edit_custom_figure_dialog.dart';
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

final class _FigureEditTestNotifier extends CollectionNotifier {
  _FigureEditTestNotifier(this._snap);
  CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;

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

  @override
  void addCustomFigure({
    required String seriesId,
    required String name,
    required bool isSecret,
    String? rarityLabel,
    String? localImageUri,
  }) {
    super.addCustomFigure(
      seriesId: seriesId,
      name: name,
      isSecret: isSecret,
      rarityLabel: rarityLabel,
      localImageUri: localImageUri,
    );
    _snap = state;
  }
}

ShelfSeries _seriesWithFigures() {
  const seriesId = 'custom_figure_edit_test';
  return ShelfSeries(
    id: seriesId,
    name: 'Rabbit Set',
    brand: 'DPL',
    ipName: 'Baby Three',
    taxonomyBrandId: 'dpl',
    taxonomyIpId: 'baby_three',
    catalogTemplateId: null,
    imageKey: seriesId,
    figures: const [
      ShelfFigure(
        id: 'custom_figure_edit_test-f-0',
        seriesId: seriesId,
        name: 'Rabbit Pink',
        rarity: 'Regular',
        isSecret: false,
        imageKey: 'custom_figure_edit_test-f-0',
        taxonomyBrandId: 'dpl',
        taxonomyIpId: 'baby_three',
      ),
      ShelfFigure(
        id: 'custom_figure_edit_test-f-1',
        seriesId: seriesId,
        name: 'Rabbit Secret',
        rarity: '1:144',
        isSecret: true,
        rarityLabel: '1:144',
        imageKey: 'custom_figure_edit_test-f-1',
        localImageUri: '/tmp/rabbit_secret.jpg',
        taxonomyBrandId: 'dpl',
        taxonomyIpId: 'baby_three',
      ),
      ShelfFigure(
        id: 'custom_figure_edit_test-f-2',
        seriesId: seriesId,
        name: 'Rabbit Black',
        rarity: 'Regular',
        isSecret: false,
        imageKey: 'custom_figure_edit_test-f-2',
        taxonomyBrandId: 'dpl',
        taxonomyIpId: 'baby_three',
      ),
    ],
    shelfAccent: Color(0xFFE4F2EA),
  );
}

Future<_FigureEditTestNotifier> _pumpEditForm(
  WidgetTester tester, {
  required ShelfSeries series,
  Future<String?> Function(BuildContext context)? pickFigureImage,
}) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final notifier = _FigureEditTestNotifier(
    CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
  );
  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(() => notifier),
        catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (ctx) {
            container = ProviderScope.containerOf(ctx);
            return Scaffold(
              body: CollectibleSheetScope(
                scrollController: ScrollController(),
                child: CustomSeriesFormSheet.edit(
                  initialSeries: series,
                  pickFigureImage: pickFigureImage,
                  onSubmit: ({
                    required String seriesName,
                    String? brand,
                    String? ipDisplayName,
                    String? customCoverImageUri,
                    String? notes,
                  }) {},
                  onFigureSubmit: ({
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
                  onFigureAdd: ({
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
        ),
      ),
    ),
  );
  await tester.pump();
  return notifier;
}

Finder _dialogNameField() {
  return find.descendant(
    of: find.byType(EditCustomFigureDialog),
    matching: find.byType(TextField),
  ).first;
}

Finder _dialogRarityField() {
  return find.descendant(
    of: find.byType(EditCustomFigureDialog),
    matching: find.byType(TextField),
  ).at(1);
}

Future<void> _tapFigure(WidgetTester tester, String figureId) async {
  final target = find.byKey(ValueKey('fig-edit-$figureId'));
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

ShelfSeries _emptyCustomSeries() {
  const seriesId = 'custom_empty_figure_edit';
  return ShelfSeries(
    id: seriesId,
    name: 'Starter Set',
    brand: 'DPL',
    ipName: 'Baby Three',
    taxonomyBrandId: 'dpl',
    taxonomyIpId: 'baby_three',
    catalogTemplateId: null,
    imageKey: seriesId,
    figures: const [],
    shelfAccent: Color(0xFFE4F2EA),
  );
}

Future<void> _startAddFigure(WidgetTester tester, String name) async {
  final field = find.byKey(const Key('custom-series-edit-add-figure-field'));
  await tester.scrollUntilVisible(
    field,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(field, name);
  await tester.tap(find.byKey(const Key('custom-series-edit-add-figure-button')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  testWidgets('Test 1: edit form shows Figures section with all figures', (
    tester,
  ) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    expect(find.text('Figures'), findsOneWidget);
    expect(find.byType(CustomSeriesEditFiguresSection), findsOneWidget);
    expect(find.text('Rabbit Pink'), findsOneWidget);
    expect(find.text('Rabbit Secret'), findsOneWidget);
    expect(find.text('Rabbit Black'), findsOneWidget);
  });

  testWidgets('Test 2: tapping a figure opens Edit Figure dialog', (
    tester,
  ) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    await _tapFigure(tester, 'custom_figure_edit_test-f-0');

    expect(find.byType(EditCustomFigureDialog), findsOneWidget);
    expect(find.text(editCustomFigureDialogTitle), findsOneWidget);
  });

  testWidgets('Test 3: edit figure name and save updates list', (
    tester,
  ) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    await _tapFigure(tester, 'custom_figure_edit_test-f-0');

    await tester.enterText(_dialogNameField(), 'Rabbit Coral');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Rabbit Coral'), findsOneWidget);
    expect(find.text('Rabbit Pink'), findsNothing);
  });

  testWidgets('Test 4: edit rarity on secret figure and save', (tester) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    await _tapFigure(tester, 'custom_figure_edit_test-f-1');

    await tester.enterText(_dialogRarityField(), '1:72');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1:72'), findsOneWidget);
  });

  testWidgets('Test 5: replace figure image via dialog and save', (
    tester,
  ) async {
    CustomFigureDraft? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showDialog<CustomFigureDraft>(
                  context: ctx,
                  builder: (_) => EditCustomFigureDialog(
                    initial: const CustomFigureDraft(displayName: 'Rabbit Black'),
                    dialogTitle: editCustomFigureDialogTitle,
                    pickImage: (_) async => '/tmp/rabbit_black_new.jpg',
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved?.localImageUri, '/tmp/rabbit_black_new.jpg');
  });

  testWidgets('shows add figure field below existing figures', (tester) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    expect(
      find.byKey(const Key('custom-series-edit-add-figure-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('custom-series-edit-add-figure-button')),
      findsOneWidget,
    );
  });

  testWidgets('add figure to populated series updates list immediately', (
    tester,
  ) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    await _startAddFigure(tester, 'Rabbit Gold');
    expect(find.byType(EditCustomFigureDialog), findsOneWidget);
    expect(find.text(addCustomFigureDialogTitle), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Rabbit Gold'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final figs = container.read(collectionNotifierProvider).shelfSeries.single.figures;
    expect(figs.length, 4);
    expect(figs.last.id, 'custom_figure_edit_test-f-3');
    expect(figs.last.name, 'Rabbit Gold');
  });

  testWidgets('add figure to empty series shows first lineup row', (
    tester,
  ) async {
    final series = _emptyCustomSeries();
    await _pumpEditForm(tester, series: series);

    await _startAddFigure(tester, 'First Fig');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('First Fig'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final figs = container.read(collectionNotifierProvider).shelfSeries.single.figures;
    expect(figs.single.id, 'custom_empty_figure_edit-f-0');
  });

  testWidgets('add secret figure via dialog saves rarity metadata', (
    tester,
  ) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    await _startAddFigure(tester, 'Hidden Rabbit');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(_dialogRarityField(), '1:288');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1:288'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures.last;
    expect(fig.isSecret, isTrue);
    expect(fig.rarityLabel, '1:288');
  });

  testWidgets('add figure with image via dialog saves local uri', (
    tester,
  ) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(
      tester,
      series: series,
      pickFigureImage: (_) async => '/tmp/rabbit_gold.jpg',
    );

    await _startAddFigure(tester, 'Rabbit Gold');
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures.last;
    expect(fig.name, 'Rabbit Gold');
    expect(fig.localImageUri, '/tmp/rabbit_gold.jpg');
  });

  testWidgets('cancel add figure dialog does not append figure', (tester) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    await _startAddFigure(tester, 'Discarded Fig');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fig-edit-custom_figure_edit_test-f-3')),
      findsNothing,
    );
    expect(find.text('3'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(
      container.read(collectionNotifierProvider).shelfSeries.single.figures.length,
      3,
    );
  });

  testWidgets('Test 5b: remove figure image from edit form saves to shelf', (
    tester,
  ) async {
    final series = _seriesWithFigures();
    await _pumpEditForm(tester, series: series);

    await _tapFigure(tester, 'custom_figure_edit_test-f-1');
    await tester.tap(find.text('Remove'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final fig = container
        .read(collectionNotifierProvider)
        .shelfSeries
        .single
        .figures[1];
    expect(fig.localImageUri, isNull);
  });
}
