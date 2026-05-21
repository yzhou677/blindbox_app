import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer newContainer() {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            figures: [
              const ShelfFigure(
                id: 'fig_cycle',
                seriesId: 'series_test',
                name: 'Cycle Me',
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cycleFigure advances none → wishlist → owned → clears', () {
    final container = newContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.cycleFigure('fig_cycle');
    expect(
      container.read(collectionNotifierProvider).trackedOrDefault('fig_cycle').state,
      FigureCollectionState.wishlist,
    );

    n.cycleFigure('fig_cycle');
    expect(
      container.read(collectionNotifierProvider).trackedOrDefault('fig_cycle').state,
      FigureCollectionState.owned,
    );

    n.cycleFigure('fig_cycle');
    expect(
      container.read(collectionNotifierProvider).figureStates.containsKey('fig_cycle'),
      isFalse,
    );
  });

  test('cycleFigure ignores unknown figure id', () {
    final container = newContainer();
    final n = container.read(collectionNotifierProvider.notifier);
    n.cycleFigure('not_on_shelf');
    expect(container.read(collectionNotifierProvider).figureStates, isEmpty);
  });

  test('addSeriesFromTemplate prepends clone and dedupes by templateId', () {
    final container = newContainer();
    final n = container.read(collectionNotifierProvider.notifier);
    final template = testCatalogTemplate(templateId: 'new_series_tpl');

    n.addSeriesFromTemplate(template);
    n.addSeriesFromTemplate(template);

    final snap = container.read(collectionNotifierProvider);
    expect(snap.shelfSeries.where((s) => s.catalogTemplateId == 'new_series_tpl'), hasLength(1));
    expect(snap.shelfSeries.first.catalogTemplateId, 'new_series_tpl');
    expect(snap.shelfSeries.first.figures.first.rarity, '1:144');
  });

  test('removeSeries drops figures from figureStates', () {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: {
          'fig_test_0': const TrackedFigure(
            figureId: 'fig_test_0',
            state: FigureCollectionState.owned,
          ),
        },
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(collectionNotifierProvider);

    container.read(collectionNotifierProvider.notifier).removeSeries('series_test');
    final snap = container.read(collectionNotifierProvider);
    expect(snap.shelfSeries, isEmpty);
    expect(snap.figureStates, isEmpty);
  });

  test('addCustomSeries skips empty figure names', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomSeries(
      seriesName: 'My Set',
      figureNames: ['  ', ''],
    );
    expect(container.read(collectionNotifierProvider).shelfSeries, isEmpty);

    n.addCustomSeries(
      seriesName: 'My Set',
      figureNames: ['Alpha'],
    );
    final added = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(added.isCustomLocal, isTrue);
    expect(added.figures.single.name, 'Alpha');
    expect(added.figures.single.rarity, 'Custom');
  });
}
