import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addSeriesFromRelease commits without imageUrl', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    const imageKey = 'the_monsters_exciting_macaron_soymilk';
    n.addSeriesFromRelease(
      SeriesRelease(
        dropId: 'drop_test',
        seriesName: 'Test Series',
        brand: 'POP MART',
        releaseDate: DateTime(2026, 3, 1),
        seriesImageKey: 'drop_test',
        heroCollectible: Collectible(
          id: 'drop_test',
          name: 'Hero',
          series: 'Test Series',
          brand: 'POP MART',
          releaseDate: DateTime(2026, 3, 1),
          imageUrl: '',
        ),
        lineup: const [
          ReleaseLineupSlot(
            slotId: imageKey,
            name: 'Soymilk',
            imageKey: imageKey,
            isSecret: false,
          ),
        ],
      ),
    );

    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures.single;
    expect(fig.imageKey, imageKey);
    expect(fig.imageUrl, isNull);
  });

  test('ShelfFigureMedia ignores cached imageUrl for catalog art', () {
    const figure = ShelfFigure(
      id: 'f1',
      seriesId: 's1',
      name: 'Fig',
      imageUrl: 'https://example.com/stale.png',
      imageKey: 'catalog_figure_key',
      rarity: 'Regular',
      isSecret: false,
    );
    const series = ShelfSeries(
      id: 's1',
      name: 'Series',
      brand: 'Brand',
      ipName: 'IP',
      figures: [figure],
      shelfAccent: Color(0xFFE8DEF5),
    );

    expect(ShelfFigureMedia.figureDisplayRef(figure, series), isNull);
    expect(ShelfFigureMedia.catalogFigureImageKey(figure), 'catalog_figure_key');
  });

  test('addSeriesFromTemplate clones imageKey without imageUrl', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    final template = CatalogSeries(
      templateId: 'tpl_a',
      name: 'Tpl',
      brand: 'Brand',
      ipName: 'IP',
      shelfAccent: const Color(0xFFE8DEF5),
      catalogCoverImageKey: 'series_cover',
      figures: const [
        CatalogFigure(
          templateFigureId: 'fig_tpl',
          catalogSeriesTemplateId: 'tpl_a',
          name: 'One',
          catalogImageKey: 'fig_key',
          imageUrl: null,
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );

    n.addSeriesFromTemplate(template);
    final cloned = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(cloned.imageKey, 'series_cover');
    final fig = cloned.figures.single;
    expect(fig.imageKey, 'fig_key');
    expect(fig.imageUrl, isNull);
  });
}
