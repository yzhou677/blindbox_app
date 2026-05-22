import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter/material.dart';
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

  test('addSeriesFromRelease stores imageKey without imageUrl', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    const imageKey = 'the_monsters_exciting_macaron_soymilk';
    final release = SeriesRelease(
      dropId: 'the_monsters_exciting_macaron',
      seriesName: 'Exciting Macaron',
      brand: 'POP MART',
      ipLine: 'POP MART · The Monsters',
      releaseDate: DateTime(2026, 3, 1),
      seriesImageKey: 'the_monsters_exciting_macaron',
      heroCollectible: Collectible(
        id: 'the_monsters_exciting_macaron',
        name: 'Soymilk',
        series: 'Exciting Macaron',
        brand: 'POP MART',
        releaseDate: DateTime(2026, 3, 1),
        imageUrl: '',
        shelfAccent: const Color(0xFFE8F5E9),
      ),
      lineup: const [
        ReleaseLineupSlot(
          slotId: imageKey,
          name: 'Soymilk',
          imageKey: imageKey,
          isSecret: false,
        ),
      ],
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'the_monsters',
    );

    n.addSeriesFromRelease(release);
    final shelf = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(shelf.catalogTemplateId, 'drop-the_monsters_exciting_macaron');
    final fig = shelf.figures.single;
    expect(fig.imageKey, imageKey);
    expect(fig.imageUrl, isNull);
  });

  test('addSeriesFromRelease dedupes when drop template already on shelf', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    final release = SeriesRelease(
      dropId: 'dedupe_drop',
      seriesName: 'Dedupe Series',
      brand: 'POP MART',
      releaseDate: DateTime(2026, 3, 1),
      seriesImageKey: 'dedupe_drop',
      heroCollectible: Collectible(
        id: 'dedupe_drop',
        name: 'Hero',
        series: 'Dedupe Series',
        brand: 'POP MART',
        releaseDate: DateTime(2026, 3, 1),
        imageUrl: '',
      ),
      lineup: const [
        ReleaseLineupSlot(
          slotId: 'slot_a',
          name: 'A',
          imageKey: 'the_monsters_exciting_macaron_soymilk',
          isSecret: false,
        ),
      ],
    );

    n.addSeriesFromRelease(release);
    n.addSeriesFromRelease(release);

    final snap = container.read(collectionNotifierProvider);
    expect(
      snap.shelfSeries.where((s) => s.catalogTemplateId == 'drop-dedupe_drop'),
      hasLength(1),
    );
  });

  test('addSeriesFromRelease leaves imageUrl null when imageKey is empty', () async {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    final release = SeriesRelease(
      dropId: 'no_key_drop',
      seriesName: 'No Key',
      brand: 'POP MART',
      releaseDate: DateTime(2026, 3, 1),
      seriesImageKey: 'no_key_drop',
      heroCollectible: Collectible(
        id: 'no_key_drop',
        name: 'Hero',
        series: 'No Key',
        brand: 'POP MART',
        releaseDate: DateTime(2026, 3, 1),
        imageUrl: '',
      ),
      lineup: const [
        ReleaseLineupSlot(
          slotId: 'slot_x',
          name: 'X',
          imageKey: '',
          isSecret: false,
        ),
      ],
    );

    n.addSeriesFromRelease(release);
    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures.single;
    expect(fig.imageKey, isNull);
    expect(fig.imageUrl, isNull);
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

  test('removeSeriesByCatalogTemplate removes shelf row and figure states', () {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(catalogTemplateId: 'drop-release-1'),
        ],
        figureStates: {
          'fig_test_0': const TrackedFigure(
            figureId: 'fig_test_0',
            state: FigureCollectionState.wishlist,
          ),
        },
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(collectionNotifierProvider);

    container
        .read(collectionNotifierProvider.notifier)
        .removeSeriesByCatalogTemplate('drop-release-1');
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
      figures: const [
        CustomFigureDraft(displayName: '  '),
      ],
    );
    expect(container.read(collectionNotifierProvider).shelfSeries, isEmpty);

    n.addCustomSeries(
      seriesName: 'My Set',
      figures: const [
        CustomFigureDraft(
          displayName: 'Alpha',
          isSecret: true,
          rarityLabel: '1:72',
        ),
      ],
    );
    final added = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(added.isCustomLocal, isTrue);
    expect(added.taxonomyBrandId, 'independent');
    expect(added.imageKey, added.id);
    final fig = added.figures.single;
    expect(fig.name, 'Alpha');
    expect(fig.isSecret, isTrue);
    expect(fig.rarityLabel, '1:72');
    expect(fig.imageKey, '${added.id}-f-0');
    expect(fig.rarity, '1:72');
  });
}
