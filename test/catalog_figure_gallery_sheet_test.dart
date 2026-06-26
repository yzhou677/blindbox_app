import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_meta.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalogFigureGalleryFigureMetaLine', () {
    test('regular figure with Regular rarity shows nothing', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_1',
        name: 'Soymilk',
        rarityLabel: 'Regular',
        isSecret: false,
      );
      expect(catalogFigureGalleryFigureMetaLine(item), isNull);
    });

    test('rarity only', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_2',
        name: 'Peach',
        rarityLabel: 'Rare',
        isSecret: false,
      );
      expect(catalogFigureGalleryFigureMetaLine(item), 'Rare');
    });

    test('odds only on secret figure shows Secret before odds', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_3',
        name: 'Hidden Cut',
        rarityLabel: '1:1152',
        isSecret: true,
      );
      expect(catalogFigureGalleryFigureMetaLine(item), 'Secret · 1:1152');
    });

    test('explicit odds field orders after rarity', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_4',
        name: 'Hidden Cut',
        rarityLabel: 'Super Rare Secret',
        oddsLabel: '1:1152',
        isSecret: true,
      );
      expect(
        catalogFigureGalleryFigureMetaLine(item),
        'Super Rare Secret · 1:1152',
      );
    });

    test('secret figure with Secret rarity does not duplicate', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_5',
        name: 'Hidden Cut',
        rarityLabel: 'Secret',
        isSecret: true,
      );
      expect(catalogFigureGalleryFigureMetaLine(item), 'Secret');
    });

    test('secret figure without rarity label shows Secret', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_6',
        name: 'Hidden Cut',
        isSecret: true,
      );
      expect(catalogFigureGalleryFigureMetaLine(item), 'Secret');
    });

    test('secret figure with other rarity keeps both labels before odds', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_7',
        name: 'Hidden Cut',
        rarityLabel: 'Ultra Rare',
        oddsLabel: '1:576',
        isSecret: true,
      );
      expect(
        catalogFigureGalleryFigureMetaLine(item),
        'Ultra Rare · Secret · 1:576',
      );
    });

    test('Super Rare Secret with odds never duplicates Secret', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_8',
        name: 'Hidden Cut',
        rarityLabel: 'Super Rare Secret',
        oddsLabel: '1:1152',
        isSecret: true,
      );
      expect(
        catalogFigureGalleryFigureMetaLine(item),
        'Super Rare Secret · 1:1152',
      );
    });

    test('secret rarity label is case-insensitive for dedup', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_9',
        name: 'Hidden Cut',
        rarityLabel: 'secret',
        isSecret: true,
      );
      expect(catalogFigureGalleryFigureMetaLine(item), 'secret');
    });

    test('combined rarity string splits odds to the end', () {
      const item = CatalogFigureGalleryItem(
        id: 'fig_10',
        name: 'Hidden Cut',
        rarityLabel: 'Super Rare Secret · 1:1152',
        isSecret: true,
      );
      expect(
        catalogFigureGalleryFigureMetaLine(item),
        'Super Rare Secret · 1:1152',
      );
    });
  });

  group('catalogFigureGalleryCaptionSecondary', () {
    test('joins series title and meta with separator', () {
      expect(
        catalogFigureGalleryCaptionSecondary(
          seriesTitle: 'THE MONSTERS Hair Salon Series Figures',
          metaLine: 'Secret · 1:1152',
        ),
        'THE MONSTERS Hair Salon Series Figures · Secret · 1:1152',
      );
    });

    test('series only when meta is empty', () {
      expect(
        catalogFigureGalleryCaptionSecondary(
          seriesTitle: 'Macaron Series',
          metaLine: null,
        ),
        'Macaron Series',
      );
    });
  });

  testWidgets('secret figure subtitle shows rarity before odds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogFigureGallerySheet(
          items: const [
            CatalogFigureGalleryItem(
              id: 'fig_secret',
              name: 'Hidden Cut',
              rarityLabel: '1:1152',
              isSecret: true,
            ),
          ],
          initialIndex: 0,
          seriesTitle: 'THE MONSTERS Hair Salon Series Figures',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('THE MONSTERS Hair Salon Series Figures · Secret · 1:1152'),
      findsOneWidget,
    );
    expect(find.textContaining('1:1152 · Secret'), findsNothing);
    expect(find.textContaining('Secret · Secret'), findsNothing);
  });

  testWidgets('page indicator fits narrow width with many figures', (tester) async {
    final items = List<CatalogFigureGalleryItem>.generate(
      33,
      (i) => CatalogFigureGalleryItem(id: 'fig_$i', name: 'Figure $i'),
    );

    await tester.binding.setSurfaceSize(const Size(384, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogFigureGallerySheet(
          items: items,
          initialIndex: 10,
          seriesTitle: 'Nommi Sweetheart Plan Series Mini Figures Surprise Bag',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('11 of 33'), findsOneWidget);
  });
}
