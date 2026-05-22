import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseFigure = ShelfFigure(
    id: 'fig_1',
    seriesId: 'series_1',
    name: 'Test',
    imageUrl: 'assets/catalog/figures/foo.png',
    rarity: 'Regular',
    isSecret: false,
  );

  const baseSeries = ShelfSeries(
    id: 'series_1',
    name: 'Series',
    brand: 'Brand',
    ipName: 'IP',
    figures: [baseFigure],
    shelfAccent: Color(0xFFE8F5E9),
    customCoverImageUri: '/covers/series.jpg',
  );

  group('ShelfFigureMedia.figureDisplayRef', () {
    test('prefers localImageUri over imageUrl', () {
      const figure = ShelfFigure(
        id: 'fig_1',
        seriesId: 'series_1',
        name: 'Test',
        localImageUri: '/device/photo.jpg',
        imageUrl: 'assets/catalog/figures/foo.png',
        rarity: 'Regular',
        isSecret: false,
      );
      expect(
        ShelfFigureMedia.figureDisplayRef(figure, baseSeries),
        '/device/photo.jpg',
      );
    });

    test('uses customCoverImageUri before imageUrl when fallback enabled', () {
      const figure = ShelfFigure(
        id: 'fig_1',
        seriesId: 'series_1',
        name: 'Test',
        imageUrl: 'assets/catalog/figures/foo.png',
        rarity: 'Regular',
        isSecret: false,
      );
      expect(
        ShelfFigureMedia.figureDisplayRef(figure, baseSeries),
        '/covers/series.jpg',
      );
    });

    test('skips series cover when includeSeriesCoverFallback is false', () {
      const figure = ShelfFigure(
        id: 'fig_1',
        seriesId: 'series_1',
        name: 'Test',
        imageUrl: 'assets/catalog/figures/foo.png',
        rarity: 'Regular',
        isSecret: false,
      );
      expect(
        ShelfFigureMedia.figureDisplayRef(
          figure,
          baseSeries,
          includeSeriesCoverFallback: false,
        ),
        'assets/catalog/figures/foo.png',
      );
    });

    test('returns null when only series cover exists and fallback disabled', () {
      const figure = ShelfFigure(
        id: 'fig_1',
        seriesId: 'series_1',
        name: 'Test',
        rarity: 'Regular',
        isSecret: false,
      );
      expect(
        ShelfFigureMedia.figureDisplayRef(
          figure,
          baseSeries,
          includeSeriesCoverFallback: false,
        ),
        isNull,
      );
    });
  });

  group('ShelfFigureMedia.seriesCoverRef', () {
    test('returns customCoverImageUri when set', () {
      expect(ShelfFigureMedia.seriesCoverRef(baseSeries), '/covers/series.jpg');
    });

    test('returns null when no custom cover', () {
      const series = ShelfSeries(
        id: 'series_1',
        name: 'Series',
        brand: 'Brand',
        ipName: 'IP',
        figures: [baseFigure],
        shelfAccent: Color(0xFFE8F5E9),
      );
      expect(ShelfFigureMedia.seriesCoverRef(series), isNull);
    });
  });
}
