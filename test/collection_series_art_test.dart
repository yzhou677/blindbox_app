import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_art.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogSeriesImageKey returns explicit imageKey when set', () {
    final series = testShelfSeries(
      catalogTemplateId: 'aespa_fluffy_club',
      imageKey: 'custom_cover_stem',
    );
    expect(
      CollectionSeriesArt.catalogSeriesImageKey(series),
      'custom_cover_stem',
    );
  });

  test('catalogSeriesImageKey falls back to template id for catalog clones', () {
    final series = testShelfSeries(catalogTemplateId: 'aespa_fluffy_club');
    expect(CollectionSeriesArt.catalogSeriesImageKey(series), 'aespa_fluffy_club');
  });

  test('catalogSeriesImageKey is null for custom local rows', () {
    expect(
      CollectionSeriesArt.catalogSeriesImageKey(
        testShelfSeries(catalogTemplateId: null),
      ),
      isNull,
    );
  });

  test('cloneCatalogSeriesOntoShelf persists catalog cover imageKey', () {
    const template = CatalogSeries(
      templateId: 'series_a',
      name: 'Series A',
      brand: 'Brand',
      ipName: 'IP',
      shelfAccent: Color(0xFFE4F2EA),
      catalogCoverImageKey: 'series_cover_stem',
      figures: [],
    );
    final shelf = cloneCatalogSeriesOntoShelf(
      template,
      'shelf-series_a-1',
      catalogTemplateKey: 'series_a',
    );
    expect(shelf.imageKey, 'series_cover_stem');
  });
}
