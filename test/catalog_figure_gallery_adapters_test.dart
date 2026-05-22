import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalogGalleryItemsFromShelfSeries', () {
    test('passes catalog imageKey for gallery resolve', () {
      const series = ShelfSeries(
        id: 'series_a',
        name: 'Macaron',
        brand: 'POP MART',
        ipName: 'The Monsters',
        figures: [
          ShelfFigure(
            id: 'fig_a',
            seriesId: 'series_a',
            name: 'Soymilk',
            imageUrl: 'assets/catalog/figures/the_monsters_exciting_macaron_soymilk.png',
            imageKey: 'the_monsters_exciting_macaron_soymilk',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
        shelfAccent: Color(0xFFE8F5E9),
      );

      final items = catalogGalleryItemsFromShelfSeries(series);
      expect(items, hasLength(1));
      expect(items.single.catalogImageKey, 'the_monsters_exciting_macaron_soymilk');
    });

    test('does not pass series cover as gallery item field', () {
      const series = ShelfSeries(
        id: 'series_b',
        name: 'Ocean',
        brand: 'POP MART',
        ipName: 'Crybaby',
        customCoverImageUri: '/covers/ocean.jpg',
        figures: [
          ShelfFigure(
            id: 'fig_b',
            seriesId: 'series_b',
            name: 'Whale',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
        shelfAccent: Color(0xFFFCE4EC),
      );

      final items = catalogGalleryItemsFromShelfSeries(series);
      expect(items.single.catalogImageKey, isNull);
      expect(items.single.localImageUri, isNull);
    });

    test('keeps catalogImageKey when imageUrl is missing on shelf row', () {
      const series = ShelfSeries(
        id: 'series_c',
        name: 'Ocean',
        brand: 'POP MART',
        ipName: 'Crybaby',
        figures: [
          ShelfFigure(
            id: 'fig_c',
            seriesId: 'series_c',
            name: 'Whale',
            imageKey: 'crybaby_cry_me_an_ocean_the_whale',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
        shelfAccent: Color(0xFFFCE4EC),
      );

      final items = catalogGalleryItemsFromShelfSeries(series);
      expect(items.single.catalogImageKey, 'crybaby_cry_me_an_ocean_the_whale');
    });
  });
}
