import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('progressForSeries', () {
    test('counts owned, wishlist, and missing slots', () {
      final series = testShelfSeries(
        figures: [
          const ShelfFigure(
            id: 'f1',
            seriesId: 's',
            name: 'A',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'f2',
            seriesId: 's',
            name: 'B',
            rarity: 'Regular',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'f3',
            seriesId: 's',
            name: 'C',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
      final states = {
        'f1': const TrackedFigure(figureId: 'f1', state: FigureCollectionState.owned),
        'f2': const TrackedFigure(figureId: 'f2', state: FigureCollectionState.wishlist),
      };
      final p = progressForSeries(series, states);
      expect(p.owned, 1);
      expect(p.wishlist, 1);
      expect(p.missing, 1);
      expect(p.completion(3), closeTo(1 / 3, 0.001));
    });
  });

  group('cloneCatalogSeriesOntoShelf', () {
    test('assigns fresh shelf ids and preserves catalog linkage', () {
      final template = testCatalogTemplate();
      final shelf = cloneCatalogSeriesOntoShelf(
        template,
        'shelf-new-1',
        catalogTemplateKey: template.templateId,
      );

      expect(shelf.id, 'shelf-new-1');
      expect(shelf.catalogTemplateId, template.templateId);
      expect(shelf.figures, hasLength(2));
      expect(shelf.figures.first.id, 'shelf-new-1-fig-0');
      expect(shelf.figures.first.catalogFigureTemplateId, 'fig_catalog_0');
      expect(shelf.figures.first.rarity, '1:144');
      expect(shelf.figures.first.isSecret, isTrue);
      expect(shelf.figures.last.rarity, 'Regular');
    });
  });

  group('CollectionSnapshot', () {
    test('hasTemplateOnShelf matches catalogTemplateId or shelf id', () {
      final snap = CollectionSnapshot(
        shelfSeries: [testShelfSeries(catalogTemplateId: 'macaron_series')],
        figureStates: const {},
      );
      expect(snap.hasTemplateOnShelf('macaron_series'), isTrue);
      expect(snap.hasTemplateOnShelf('series_test'), isTrue);
      expect(snap.hasTemplateOnShelf('other'), isFalse);
    });

    test('aggregates totals and average completion', () {
      final series = testShelfSeries(
        figures: [
          const ShelfFigure(
            id: 'a',
            seriesId: 'series_test',
            name: 'A',
            rarity: 'R',
            isSecret: false,
          ),
          const ShelfFigure(
            id: 'b',
            seriesId: 'series_test',
            name: 'B',
            rarity: 'R',
            isSecret: false,
          ),
        ],
      );
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          'a': const TrackedFigure(figureId: 'a', state: FigureCollectionState.owned),
        },
      );
      expect(snap.totalShelfFigures, 2);
      expect(snap.totalOwnedFigures, 1);
      expect(snap.totalWishlistFigures, 0);
      expect(snap.averageCompletionPercent, 50);
      expect(snap.isWarmStart, isFalse);
    });

    test('isWarmStart when no tracked figures', () {
      final snap = CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      );
      expect(snap.isWarmStart, isTrue);
    });

    test('trackedOrDefault returns none for unknown figure', () {
      final snap = CollectionSnapshot.emptyTest();
      expect(snap.trackedOrDefault('missing').state, FigureCollectionState.none);
    });
  });

  group('ShelfSeries flags', () {
    test('isCustomLocal and isDropImport', () {
      expect(
        testShelfSeries(catalogTemplateId: null).isCustomLocal,
        isTrue,
      );
      expect(
        ShelfSeries(
          id: 'd1',
          name: 'Drop',
          brand: 'B',
          ipName: 'I',
          figures: const [],
          shelfAccent: const Color(0xFFE4F2EA),
          catalogTemplateId: 'drop-abc',
        ).isDropImport,
        isTrue,
      );
      expect(testShelfSeries().isDropImport, isFalse);
    });
  });

  group('shelfIpLabelFromBrandLine', () {
    test('strips legacy brand · ip prefix', () {
      expect(
        shelfIpLabelFromBrandLine(
          brand: 'POP MART',
          line: 'POP MART · Crybaby',
        ),
        'Crybaby',
      );
    });

    test('keeps plain IP name', () {
      expect(
        shelfIpLabelFromBrandLine(brand: 'POP MART', line: 'Crybaby'),
        'Crybaby',
      );
    });
  });
}
