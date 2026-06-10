import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
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

final class _IntegrationCollectionNotifier extends CollectionNotifier {
  _IntegrationCollectionNotifier(this._snap);
  CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;

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

ShelfSeries _integrationSeries() {
  const seriesId = 'custom_integration_add';
  return ShelfSeries(
    id: seriesId,
    name: 'Weekend Finds',
    brand: 'DPL',
    ipName: 'Baby Three',
    taxonomyBrandId: 'dpl',
    taxonomyIpId: 'baby_three',
    catalogTemplateId: null,
    imageKey: seriesId,
    figures: const [
      ShelfFigure(
        id: 'custom_integration_add-f-0',
        seriesId: seriesId,
        name: 'Starter',
        rarity: 'Regular',
        isSecret: false,
        imageKey: 'custom_integration_add-f-0',
        taxonomyBrandId: 'dpl',
        taxonomyIpId: 'baby_three',
      ),
    ],
    shelfAccent: Color(0xFFE4F2EA),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  testWidgets('figures sheet edit series path can add a new figure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final series = _integrationSeries();
    final notifier = _IntegrationCollectionNotifier(
      CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(() => notifier),
          catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => CollectibleSheetScope(
                      scrollController: ScrollController(),
                      child: SeriesFiguresSheet(seriesId: series.id),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Edit series'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final addField = find.byKey(const Key('custom-series-edit-add-figure-field'));
    await tester.scrollUntilVisible(
      addField,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(addField, 'Late Add');
    await tester.tap(find.byKey(const Key('custom-series-edit-add-figure-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('fig-edit-custom_integration_add-f-1')),
      findsOneWidget,
    );
    expect(
      notifier.state.shelfSeries.single.figures.map((f) => f.name),
      ['Starter', 'Late Add'],
    );
    expect(
      notifier.state.shelfSeries.single.figures.last.id,
      'custom_integration_add-f-1',
    );

    await tester.pump(const Duration(milliseconds: 400));
  });
}
