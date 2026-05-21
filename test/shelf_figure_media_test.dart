import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('figure ref prefers localImageUri over cover and imageUrl', () {
    final fig = ShelfFigure(
      id: 'f',
      seriesId: 's',
      name: 'F',
      imageUrl: 'https://example.com/a.jpg',
      localImageUri: '/tmp/a.png',
      rarity: 'R',
      isSecret: false,
    );
    final s = ShelfSeries(
      id: 's',
      name: 'S',
      brand: 'B',
      ipName: 'I',
      figures: [fig],
      shelfAccent: const Color(0xFFE4F2EA),
      customCoverImageUri: 'file:///cover.jpg',
    );
    expect(ShelfFigureMedia.figureDisplayRef(fig, s), '/tmp/a.png');
  });

  test('figure ref uses series cover when no local', () {
    final fig = ShelfFigure(
      id: 'f',
      seriesId: 's',
      name: 'F',
      imageUrl: 'https://last',
      localImageUri: null,
      rarity: 'R',
      isSecret: false,
    );
    final s = ShelfSeries(
      id: 's',
      name: 'S',
      brand: 'B',
      ipName: 'I',
      figures: [fig],
      shelfAccent: const Color(0xFFE4F2EA),
      customCoverImageUri: '/cover.png',
    );
    expect(ShelfFigureMedia.figureDisplayRef(fig, s), '/cover.png');
  });

  test('figure ref falls back to imageUrl (catalog path)', () {
    final fig = ShelfFigure(
      id: 'f',
      seriesId: 's',
      name: 'F',
      imageUrl: 'assets/catalog/figures/x.png',
      localImageUri: null,
      rarity: 'R',
      isSecret: false,
    );
    final s = ShelfSeries(
      id: 's',
      name: 'S',
      brand: 'B',
      ipName: 'I',
      figures: [fig],
      shelfAccent: const Color(0xFFE4F2EA),
    );
    expect(ShelfFigureMedia.figureDisplayRef(fig, s), 'assets/catalog/figures/x.png');
  });

  test('series cover ref returns custom cover only', () {
    final fig = ShelfFigure(
      id: 'f',
      seriesId: 's',
      name: 'F',
      imageUrl: 'assets/a.png',
      rarity: 'R',
      isSecret: false,
    );
    final s = ShelfSeries(
      id: 's',
      name: 'S',
      brand: 'B',
      ipName: 'I',
      figures: [fig],
      shelfAccent: const Color(0xFFE4F2EA),
      customCoverImageUri: '/me.jpg',
    );
    expect(ShelfFigureMedia.seriesCoverRef(s), '/me.jpg');
  });

  test('series cover ref ignores figure imageUrl', () {
    final fig = ShelfFigure(
      id: 'f',
      seriesId: 's',
      name: 'F',
      imageUrl: 'assets/catalog/figures/x.png',
      rarity: 'R',
      isSecret: false,
    );
    final s = ShelfSeries(
      id: 's',
      name: 'S',
      brand: 'B',
      ipName: 'I',
      figures: [fig],
      shelfAccent: const Color(0xFFE4F2EA),
      catalogTemplateId: 'some_series_id',
    );
    expect(ShelfFigureMedia.seriesCoverRef(s), isNull);
  });
}
