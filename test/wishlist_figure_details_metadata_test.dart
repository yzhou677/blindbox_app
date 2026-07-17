import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/wishlist_figure_details_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WishlistFigureDetailsMetadata', () {
    test('separates regular figure type from known odds', () {
      const figure = ShelfFigure(
        id: 'regular_with_odds',
        seriesId: 'series',
        name: 'Regular Pull',
        rarity: '1:72',
        isSecret: false,
      );

      expect(WishlistFigureDetailsMetadata.typeLabel(figure), 'Regular Figure');
      expect(WishlistFigureDetailsMetadata.oddsLabel(figure), '1:72');
    });

    test('separates secret figure type from known odds', () {
      const figure = ShelfFigure(
        id: 'secret_with_odds',
        seriesId: 'series',
        name: 'Secret Pull',
        rarity: 'Secret',
        rarityLabel: '1 : 144',
        isSecret: true,
      );

      expect(WishlistFigureDetailsMetadata.typeLabel(figure), 'Secret Figure');
      expect(WishlistFigureDetailsMetadata.oddsLabel(figure), '1:144');
    });

    test('omits odds when unavailable', () {
      const figure = ShelfFigure(
        id: 'secret_unknown_odds',
        seriesId: 'series',
        name: 'Secret Pull',
        rarity: 'Secret',
        isSecret: true,
      );

      expect(WishlistFigureDetailsMetadata.typeLabel(figure), 'Secret Figure');
      expect(WishlistFigureDetailsMetadata.oddsLabel(figure), isNull);
    });

    test('extracts odds from combined legacy rarity text', () {
      const figure = ShelfFigure(
        id: 'legacy_combined',
        seriesId: 'series',
        name: 'Legacy Pull',
        rarity: 'Super Rare Secret · 1:1152',
        isSecret: true,
      );

      expect(WishlistFigureDetailsMetadata.typeLabel(figure), 'Secret Figure');
      expect(WishlistFigureDetailsMetadata.oddsLabel(figure), '1:1152');
    });
  });
}
