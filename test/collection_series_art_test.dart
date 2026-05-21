import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_art.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogSeriesImageKey returns template id for catalog clones', () {
    final series = testShelfSeries(catalogTemplateId: 'aespa_fluffy_club');
    expect(CollectionSeriesArt.catalogSeriesImageKey(series), 'aespa_fluffy_club');
  });

  test('catalogSeriesImageKey is null for custom and drop imports', () {
    expect(
      CollectionSeriesArt.catalogSeriesImageKey(
        testShelfSeries(catalogTemplateId: null),
      ),
      isNull,
    );
    expect(
      CollectionSeriesArt.catalogSeriesImageKey(
        ShelfSeries(
          id: 'd',
          name: 'Drop',
          brand: 'B',
          ipName: 'I',
          figures: const [],
          shelfAccent: const Color(0xFFE4F2EA),
          catalogTemplateId: 'drop-x',
        ),
      ),
      isNull,
    );
  });

  test('anchorFigure returns first figure or null', () {
    expect(CollectionSeriesArt.anchorFigure(testShelfSeries())!.name, 'Test Figure');
    expect(
      CollectionSeriesArt.anchorFigure(
        ShelfSeries(
          id: 'e',
          name: 'E',
          brand: 'B',
          ipName: 'I',
          figures: const [],
          shelfAccent: const Color(0xFFE4F2EA),
        ),
      ),
      isNull,
    );
  });
}
